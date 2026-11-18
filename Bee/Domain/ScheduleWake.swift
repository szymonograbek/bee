import Foundation

/// Waking a sleeping Mac just before the schedule starts keeping it awake.
enum ScheduleWake {
    /// Leaves the Mac time to reconnect to the network before the window starts.
    static let lead: TimeInterval = 60

    /// When to wake the Mac for the next scheduled window, or nil when none is ahead. Skips windows that start
    /// during a pause, since Bee would let the Mac sleep through them anyway.
    static func next(for state: BeeState, after now: Date, calendar: Calendar) -> Date? {
        var earliestStart = now.addingTimeInterval(lead)
        if case let .paused(until) = state.mode.expired(at: now) {
            earliestStart = max(earliestStart, until)
        }
        return state.schedule.nextWindowStart(after: earliestStart, calendar: calendar)?.addingTimeInterval(-lead)
    }
}
