import AppKit
import Observation

/// Owns `BeeState` and every effect derived from it: the power assertion, disabled sleep, naps, Bluetooth, timers,
/// pollers, and persistence.
@MainActor
@Observable
final class BeeController {
    private(set) var state: BeeState
    private(set) var activity: Activity
    private(set) var preventsDisplaySleep: Bool
    private(set) var keepsAwakeForT3AutoResume: Bool
    private(set) var loginItem: LoginItemStatus
    private(set) var keepsAwakeWithLidClosed: Bool
    private(set) var lidBluetooth: LidBluetooth
    private(set) var lidBluetoothDevices: Set<BluetoothAddress>
    let bluetoothPermission = BluetoothPermission()
    private(set) var sleepsUntilAutoResume: Bool

    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let power = PowerAssertion()
    @ObservationIgnored private let sleepDisabler: SleepDisabler
    @ObservationIgnored private let napper: ResumeNapper
    @ObservationIgnored private let bluetooth: LidBluetoothSwitch
    @ObservationIgnored private let presence = PresenceMonitor()
    @ObservationIgnored private var lastSaved: Snapshot
    @ObservationIgnored private var wakeTask: Task<Void, Never>?
    @ObservationIgnored private let pollers = IntegrationPollers()
    @ObservationIgnored private var powerWatcher: Task<Void, Never>?
    @ObservationIgnored private var lidWatcher: Task<Void, Never>?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    static func live() -> BeeController {
        BeeController(defaults: .standard, calendar: .autoupdatingCurrent)
    }

    private init(defaults: UserDefaults, calendar: Calendar) {
        let snapshot = Snapshot.load(from: defaults)
        let integrations = Dictionary(uniqueKeysWithValues: IntegrationID.allCases.map { id in
            (id, snapshot.enabledIntegrations.contains(id) ? IntegrationState.checking : .disabled)
        })
        let state = BeeState(
            mode: snapshot.mode,
            schedule: snapshot.schedule,
            integrations: integrations,
            batteryLimit: snapshot.batteryLimit,
            power: PowerSourceReader.current()
        )
        self.state = state
        self.activity = state.activity(at: Date(), calendar: calendar)
        self.preventsDisplaySleep = snapshot.preventsDisplaySleep
        self.keepsAwakeForT3AutoResume = snapshot.keepsAwakeForT3AutoResume
        self.loginItem = LoginItem.status
        self.keepsAwakeWithLidClosed = snapshot.keepsAwakeWithLidClosed
        self.lidBluetooth = snapshot.lidBluetooth
        self.lidBluetoothDevices = snapshot.lidBluetoothDevices
        self.sleepsUntilAutoResume = snapshot.sleepsUntilAutoResume
        let sleepDisabler = SleepDisabler(defaults: defaults)
        self.sleepDisabler = sleepDisabler
        self.napper = ResumeNapper(sleepDisabler: sleepDisabler)
        self.bluetooth = LidBluetoothSwitch(defaults: defaults)
        self.calendar = calendar
        self.defaults = defaults
        self.lastSaved = snapshot
        observeSystemEvents()
        watchPowerSource()
        watchLid()
        // Normalizes a persisted pause or keep-awake that expired while Bee was not running.
        send(.tick)
        refreshPermissions()
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
        case let .setBatteryLimit(limit):
            send(.batteryLimitChanged(limit))
        case let .setLidBluetooth(choice, devices):
            if choice == .disconnectChosen, lidBluetooth != choice { bluetoothPermission.request() }
            lidBluetooth = choice
            lidBluetoothDevices = devices
            reconcile()
        case let .setOption(option, isOn):
            setOption(option, isOn)
        }
    }

    func isEnabled(_ id: IntegrationID) -> Bool {
        state.integrations[id] != .disabled
    }

    var lidSleepPermission: SudoPermission.State {
        sleepDisabler.permission.state
    }

    var resumeNapPermission: SudoPermission.State {
        napper.permission.state
    }

    /// Re-reads what the user can change outside Bee: login items and sudoers.
    func refreshSystemStatus() {
        loginItem = LoginItem.status
        refreshPermissions()
    }

    private func refreshPermissions() {
        sleepDisabler.refreshPermission()
        Task { await napper.permission.refresh() }
    }

    // MARK: State

    private func send(_ event: BeeEvent) {
        var next = state
        next.handle(event, at: Date())
        if next != state { state = next }
        reconcile()
    }

    private func setOption(_ option: BeeOption, _ isOn: Bool) {
        switch option {
        case let .integration(id):
            guard isOn != isEnabled(id) else { return }
            send(.integrationChanged(id, isOn ? .checking : .disabled))
        case .launchAtLogin:
            loginItem = LoginItem.set(isOn)
        case .preventsDisplaySleep:
            preventsDisplaySleep = isOn
            reconcile()
        case .keepsAwakeWithLidClosed:
            setNeedingRoot(\.keepsAwakeWithLidClosed, isOn) { await $0.sleepDisabler.requestPermission() }
        case .sleepsUntilAutoResume:
            setNeedingRoot(\.sleepsUntilAutoResume, isOn) { await $0.napper.permission.request() }
        case .keepsAwakeForT3AutoResume:
            keepsAwakeForT3AutoResume = isOn
            restartPollers()
        }
    }

    /// Level-triggered: brings every effect in line with the current state, so running it twice is harmless.
    private func reconcile() {
        let now = Date()
        let current = state.activity(at: now, calendar: calendar)
        if current != activity { activity = current }
        let presence = presence.current(at: now)
        let nap = sleepsUntilAutoResume ? ResumeNap.wake(for: current, presence: presence, at: now) : nil
        let keepsAwake = current.isAwake && nap == nil
        power.hold(keepsAwake ? (preventsDisplaySleep ? .display : .system) : nil)
        sleepDisabler.hold(keepsAwake && keepsAwakeWithLidClosed ? .disabled : .allowed)
        // After the sleep disabler, which the napper waits on before sleeping.
        napper.hold(wakingAt: nap)
        bluetooth.hold(presence.isPutAway ? lidBluetooth : .leaveOn, devices: lidBluetoothDevices)
        save()
        let napCheck = sleepsUntilAutoResume ? ResumeNap.nextCheck(for: current, presence: presence, at: now) : nil
        armWake(now: now, napCheck: napCheck)
        reconcilePollers()
    }

    private func save() {
        let snapshot = Snapshot(
            mode: state.mode,
            schedule: state.schedule,
            enabledIntegrations: Set(IntegrationID.allCases.filter(isEnabled)),
            preventsDisplaySleep: preventsDisplaySleep,
            keepsAwakeWithLidClosed: keepsAwakeWithLidClosed,
            lidBluetooth: lidBluetooth,
            lidBluetoothDevices: lidBluetoothDevices,
            keepsAwakeForT3AutoResume: keepsAwakeForT3AutoResume,
            sleepsUntilAutoResume: sleepsUntilAutoResume,
            batteryLimit: state.batteryLimit
        )
        guard snapshot != lastSaved else { return }
        snapshot.save(to: defaults)
        lastSaved = snapshot
    }
}

// MARK: Time and system events
extension BeeController {
    /// Capped so a missed wall-clock adjustment can never leave Bee stale for long. `napCheck` is when an idle user
    /// will count as away.
    private func armWake(now: Date, napCheck: Date?) {
        wakeTask?.cancel()
        let cap = now.addingTimeInterval(5 * 60)
        let candidates = [state.nextTransition(after: now, calendar: calendar), napCheck, cap]
        let deadline = candidates.compactMap(\.self).min() ?? cap
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
        // Readings taken before sleep are stale.
        observe(NSWorkspace.didWakeNotification, on: workspace) { bee in
            bee.presence.noteWake()
            bee.restartPollers()
        }
        observe(NSApplication.didChangeScreenParametersNotification, on: .default) { $0.reconcile() }
        observe(NSApplication.willTerminateNotification, on: .default) { $0.sleepDisabler.releaseBeforeExit() }
        let timeChanges: [Notification.Name] = [
            .NSSystemClockDidChange,
            .NSSystemTimeZoneDidChange,
            .NSCalendarDayChanged
        ]
        for name in timeChanges {
            observe(name, on: .default) { $0.send(.tick) }
        }
    }

    private func watchPowerSource() {
        powerWatcher = Task { [weak self] in
            for await _ in PowerSourceReader.changes() {
                self?.send(.powerChanged(PowerSourceReader.current()))
            }
        }
    }

    private func watchLid() {
        lidWatcher = Task { [weak self] in
            for await _ in PresenceMonitor.lidChanges() {
                self?.reconcile()
            }
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

    // MARK: Settings that need root

    /// Turning one on without permission installs the sudoers rule first, and the setting only sticks once sudo
    /// confirms it.
    private func setNeedingRoot(
        _ setting: ReferenceWritableKeyPath<BeeController, Bool>,
        _ isOn: Bool,
        grant: @escaping @MainActor (BeeController) async -> Bool
    ) {
        guard isOn else {
            self[keyPath: setting] = false
            reconcile()
            return
        }
        Task {
            guard await grant(self) else { return }
            self[keyPath: setting] = true
            reconcile()
        }
    }
}

// MARK: Integrations
extension BeeController {
    /// Every poller starts over with an immediate read.
    private func restartPollers() {
        pollers.stopAll()
        send(.tick)
    }

    private func reconcilePollers() {
        let enabled = Set(IntegrationID.allCases.filter(isEnabled))
        pollers.reconcile(enabled: enabled, make: integration) { [weak self] id, reading in
            self?.send(.integrationChanged(id, .reported(reading)))
        }
    }

    private func integration(_ id: IntegrationID) -> any Integration {
        switch id {
        case .t3Code: T3Integration(keepsAwakeForAutoResume: keepsAwakeForT3AutoResume)
        case .claudeCode: ClaudeIntegration()
        case .codex: CodexIntegration()
        }
    }
}
