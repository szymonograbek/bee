import Foundation

/// The user's manual choice, layered on top of the schedule and integrations.
enum Mode: Codable, Equatable, Sendable {
    /// Schedule and integrations decide.
    case automatic
    /// Awake regardless of schedule and integrations.
    case keepAwake(Expiry)
    /// Never awake, even if the schedule or an integration asks for it.
    case paused(until: Date)

    enum Expiry: Codable, Equatable, Sendable {
        case never
        case at(Date)
    }

    /// The moment this mode reverts to `.automatic` on its own.
    var expiresAt: Date? {
        switch self {
        case .automatic, .keepAwake(.never): nil
        case let .keepAwake(.at(date)), let .paused(until: date): date
        }
    }

    func expired(at now: Date) -> Self {
        guard let expiresAt, expiresAt <= now else { return self }
        return .automatic
    }
}

/// Preset lengths for "Keep Awake".
enum KeepAwakeDuration: CaseIterable, Sendable {
    case minutes15
    case minutes30
    case hour1
    case hours2
    case hours4
    case hours8
    case indefinitely

    func expiry(from now: Date) -> Mode.Expiry {
        switch self {
        case .minutes15: .at(now.addingTimeInterval(15 * 60))
        case .minutes30: .at(now.addingTimeInterval(30 * 60))
        case .hour1: .at(now.addingTimeInterval(60 * 60))
        case .hours2: .at(now.addingTimeInterval(2 * 60 * 60))
        case .hours4: .at(now.addingTimeInterval(4 * 60 * 60))
        case .hours8: .at(now.addingTimeInterval(8 * 60 * 60))
        case .indefinitely: .never
        }
    }
}

/// Preset ends for "Pause".
enum PauseLength: CaseIterable, Sendable {
    case hour1
    case restOfToday
    case restOfWeek

    func end(from now: Date, calendar: Calendar) -> Date {
        switch self {
        case .hour1:
            now.addingTimeInterval(60 * 60)
        case .restOfToday:
            calendar.dateInterval(of: .day, for: now)?.end ?? now.addingTimeInterval(24 * 60 * 60)
        case .restOfWeek:
            calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now.addingTimeInterval(7 * 24 * 60 * 60)
        }
    }
}
