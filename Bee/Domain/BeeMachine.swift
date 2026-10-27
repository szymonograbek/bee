import Foundation

/// Everything that decides whether the Mac should stay awake.
struct BeeState: Equatable, Sendable {
    var mode: Mode
    var schedule: Schedule
    var integrations: [IntegrationID: IntegrationState]
    var batteryLimit: BatteryLimit
    var power: PowerSource
}

enum BeeEvent: Equatable, Sendable {
    case keepAwake(Mode.Expiry)
    case pause(until: Date)
    case resumeAutomatic
    case scheduleChanged(Schedule)
    case integrationChanged(IntegrationID, IntegrationState)
    case batteryLimitChanged(BatteryLimit)
    case powerChanged(PowerSource)
    /// Time passed; lets timed modes expire.
    case tick
}

/// The resolved outcome of `BeeState` at a moment in time.
enum Activity: Equatable, Sendable {
    case awake(AwakeReason)
    case idle(IdleReason)

    var isAwake: Bool {
        if case .awake = self { return true }
        return false
    }
}

enum AwakeReason: Equatable, Sendable {
    case manual(Mode.Expiry)
    case schedule(until: Date)
    case integration(IntegrationID, summary: String)
    case awaitingResume(IntegrationID, at: Date)
}

enum IdleReason: Equatable, Sendable {
    case paused(until: Date)
    case lowBattery(charge: Int, limit: Int)
    case nothingActive(nextScheduledStart: Date?)
}

extension BeeState {
    /// The only way state changes. Timed modes expire before the event is applied.
    mutating func handle(_ event: BeeEvent, at now: Date) {
        mode = mode.expired(at: now)
        switch event {
        case let .keepAwake(expiry):
            mode = .keepAwake(expiry)
        case let .pause(until):
            mode = until > now ? .paused(until: until) : .automatic
        case .resumeAutomatic:
            mode = .automatic
        case let .scheduleChanged(newSchedule):
            schedule = newSchedule
        case let .integrationChanged(id, state):
            integrations[id] = state
        case let .batteryLimitChanged(limit):
            batteryLimit = limit
        case let .powerChanged(source):
            power = source
        case .tick:
            break
        }
    }

    /// Precedence: pause > low battery > manual keep-awake > schedule > active integrations > awaited resumes.
    func activity(at now: Date, calendar: Calendar) -> Activity {
        let mode = mode.expired(at: now)
        if case let .paused(until) = mode {
            return .idle(.paused(until: until))
        }
        if let charge = batteryLimit.lowCharge(on: power) {
            return .idle(.lowBattery(charge: charge, limit: batteryLimit.minimumCharge))
        }
        if case let .keepAwake(expiry) = mode {
            return .awake(.manual(expiry))
        }
        if let end = schedule.activeWindowEnd(at: now, calendar: calendar) {
            return .awake(.schedule(until: end))
        }
        if let (id, summary) = firstActiveIntegration {
            return .awake(.integration(id, summary: summary))
        }
        if let (id, resumeAt) = firstAwaitedResume {
            return .awake(.awaitingResume(id, at: resumeAt))
        }
        return .idle(.nothingActive(nextScheduledStart: schedule.nextWindowStart(after: now, calendar: calendar)))
    }

    /// The next moment `activity` can change without an event, so callers can wake up exactly then.
    /// Integration and power changes arrive as events and are not included.
    func nextTransition(after now: Date, calendar: Calendar) -> Date? {
        let candidates = [
            mode.expiresAt,
            schedule.activeWindowEnd(at: now, calendar: calendar),
            schedule.nextWindowStart(after: now, calendar: calendar)
        ]
        return candidates.compactMap(\.self).filter { $0 > now }.min()
    }

    private var firstActiveIntegration: (IntegrationID, String)? {
        IntegrationID.allCases.lazy
            .compactMap { id in self.integrations[id]?.activeSummary.map { (id, $0) } }
            .first
    }

    private var firstAwaitedResume: (IntegrationID, Date)? {
        IntegrationID.allCases.lazy
            .compactMap { id in self.integrations[id]?.resumeAt.map { (id, $0) } }
            .first
    }
}
