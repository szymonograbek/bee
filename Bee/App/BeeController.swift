import AppKit
import Observation
import ServiceManagement

/// What the UI can ask for. Presets rather than timestamps: the controller owns the clock and calendar.
enum BeeCommand: Equatable {
    case keepAwake(KeepAwakeDuration)
    case pause(PauseLength)
    case resumeAutomatic
    case setSchedule(Schedule)
    case setIntegration(IntegrationID, enabled: Bool)
    case setPreventsDisplaySleep(Bool)
    case setLaunchAtLogin(Bool)
}

/// Mirrors `SMAppService.mainApp.status`, which is the source of truth, so it is never persisted.
enum LoginItemStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case failed(String)
}

/// Owns `BeeState` and every effect derived from it: the power assertion, timers, pollers, and persistence.
@MainActor
@Observable
final class BeeController {
    private(set) var state: BeeState
    private(set) var activity: Activity
    private(set) var preventsDisplaySleep: Bool
    private(set) var loginItem: LoginItemStatus

    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let power = PowerAssertion()
    @ObservationIgnored private var lastSaved: Snapshot
    @ObservationIgnored private var wakeTask: Task<Void, Never>?
    @ObservationIgnored private var pollers: [IntegrationID: Task<Void, Never>] = [:]
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    static func live() -> BeeController {
        BeeController(defaults: .standard, calendar: .autoupdatingCurrent)
    }

    private init(defaults: UserDefaults, calendar: Calendar) {
        let snapshot = Snapshot.load(from: defaults)
        let integrations = Dictionary(uniqueKeysWithValues: IntegrationID.allCases.map { id in
            (id, snapshot.enabledIntegrations.contains(id) ? IntegrationState.checking : .disabled)
        })
        let state = BeeState(mode: snapshot.mode, schedule: snapshot.schedule, integrations: integrations)
        self.state = state
        self.activity = state.activity(at: Date(), calendar: calendar)
        self.preventsDisplaySleep = snapshot.preventsDisplaySleep
        self.loginItem = Self.currentLoginItemStatus()
        self.calendar = calendar
        self.defaults = defaults
        self.lastSaved = snapshot
        observeSystemEvents()
        // Normalizes a persisted pause or keep-awake that expired while Bee was not running.
        send(.tick)
    }

    func perform(_ command: BeeCommand) {
        let now = Date()
        switch command {
        case let .keepAwake(duration):
            send(.keepAwake(duration.expiry(from: now)))
        case let .pause(length):
            send(.pause(until: length.end(from: now, calendar: calendar)))
        case .resumeAutomatic:
            send(.resumeAutomatic)
        case let .setSchedule(schedule):
            send(.scheduleChanged(schedule))
        case let .setIntegration(id, enabled):
            setIntegration(id, enabled: enabled)
        case let .setPreventsDisplaySleep(prevents):
            preventsDisplaySleep = prevents
            reconcile()
        case let .setLaunchAtLogin(launches):
            setLaunchAtLogin(launches)
        }
    }

    func isEnabled(_ id: IntegrationID) -> Bool {
        state.integrations[id] != .disabled
    }

    func refreshLoginItem() {
        loginItem = Self.currentLoginItemStatus()
    }

    // MARK: State

    private func send(_ event: BeeEvent) {
        var next = state
        next.handle(event, at: Date())
        if next != state { state = next }
        reconcile()
    }

    private func setIntegration(_ id: IntegrationID, enabled: Bool) {
        guard enabled != isEnabled(id) else { return }
        send(.integrationChanged(id, enabled ? .checking : .disabled))
    }

    /// Level-triggered: brings every effect in line with the current state, so running it twice is harmless.
    private func reconcile() {
        let now = Date()
        let current = state.activity(at: now, calendar: calendar)
        if current != activity { activity = current }
        power.hold(current.isAwake ? (preventsDisplaySleep ? .display : .system) : nil)
        save()
        armWake(now: now)
        reconcilePollers()
    }

    private func save() {
        let snapshot = Snapshot(
            mode: state.mode,
            schedule: state.schedule,
            enabledIntegrations: Set(IntegrationID.allCases.filter(isEnabled)),
            preventsDisplaySleep: preventsDisplaySleep
        )
        guard snapshot != lastSaved else { return }
        snapshot.save(to: defaults)
        lastSaved = snapshot
    }

    // MARK: Time

    /// Capped so a missed wall-clock adjustment can never leave Bee stale for long.
    private func armWake(now: Date) {
        wakeTask?.cancel()
        let cap = now.addingTimeInterval(5 * 60)
        let deadline = min(state.nextTransition(after: now, calendar: calendar) ?? cap, cap)
        wakeTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(deadline.timeIntervalSince(now)))
            } catch {
                return
            }
            self?.send(.tick)
        }
    }

    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(NSWorkspace.didWakeNotification, on: workspace) { $0.systemDidWake() }
        let timeChanges: [Notification.Name] = [
            .NSSystemClockDidChange,
            .NSSystemTimeZoneDidChange,
            .NSCalendarDayChanged
        ]
        for name in timeChanges {
            observe(name, on: .default) { $0.send(.tick) }
        }
    }

    private func observe(
        _ name: Notification.Name,
        on center: NotificationCenter,
        perform action: @escaping @MainActor @Sendable (BeeController) -> Void
    ) {
        let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self { action(self) }
            }
        }
        observers.append(observer)
    }

    /// Readings taken before sleep are stale, so every poller starts over with an immediate read.
    private func systemDidWake() {
        for task in pollers.values { task.cancel() }
        pollers.removeAll()
        send(.tick)
    }

    // MARK: Integrations

    private func reconcilePollers() {
        for id in IntegrationID.allCases {
            if isEnabled(id), pollers[id] == nil {
                pollers[id] = startPoller(id)
            } else if !isEnabled(id), let poller = pollers.removeValue(forKey: id) {
                poller.cancel()
            }
        }
    }

    /// One sequential loop per integration, so reads never overlap. Cancellation also kills child processes.
    private func startPoller(_ id: IntegrationID) -> Task<Void, Never> {
        Task { [weak self] in
            while !Task.isCancelled {
                let reading = await Self.read(id)
                guard !Task.isCancelled else { return }
                self?.send(.integrationChanged(id, .reported(reading)))
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    nonisolated private static func read(_ id: IntegrationID) async -> IntegrationReading {
        switch id {
        case .t3Code: await T3Integration().read()
        }
    }

    // MARK: Login item

    private func setLaunchAtLogin(_ launches: Bool) {
        do {
            if launches {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshLoginItem()
        } catch {
            loginItem = .failed(error.localizedDescription)
        }
    }

    private static func currentLoginItemStatus() -> LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered, .notFound: .disabled
        @unknown default: .disabled
        }
    }
}

/// Everything Bee remembers across launches, stored as one value under one key.
private struct Snapshot: Codable, Equatable {
    var mode: Mode
    var schedule: Schedule
    var enabledIntegrations: Set<IntegrationID>
    var preventsDisplaySleep: Bool

    private static let key = "bee.snapshot.v1"
    private static let firstLaunch = Self(
        mode: .automatic,
        schedule: .workHours,
        enabledIntegrations: [.t3Code],
        preventsDisplaySleep: false
    )

    /// A missing or unreadable value falls back to first-launch defaults rather than failing to start.
    static func load(from defaults: UserDefaults) -> Self {
        guard
            let data = defaults.data(forKey: key),
            let snapshot = try? JSONDecoder().decode(Self.self, from: data)
        else { return firstLaunch }
        return snapshot
    }

    func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
