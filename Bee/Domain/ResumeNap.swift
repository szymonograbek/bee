import Foundation

/// Whether someone is at the Mac.
struct Presence: Equatable, Sendable {
    var isLidClosed: Bool
    var hasExternalDisplay: Bool
    /// Since the last keyboard or mouse input, or since the Mac last woke or its lid opened, whichever is later.
    var idleTime: TimeInterval

    /// The lid is closed with no external display, so the Mac is put away rather than used as a workstation.
    var isPutAway: Bool {
        isLidClosed && !hasExternalDisplay
    }
}

/// Letting the Mac sleep while it only waits for an auto-resume and nobody is using it, then waking it just before
/// the resume.
enum ResumeNap {
    static let awayAfter: TimeInterval = 5 * 60
    /// Leaves the Mac time to reconnect to the network before the resume.
    static let wakeLead: TimeInterval = 60
    /// A shorter nap isn't worth a sleep and a wake. Also keeps the Mac from napping again right after the wake.
    static let shortestNap: TimeInterval = 2 * 60

    /// When to wake the Mac if it should sleep now, or nil to keep it awake.
    static func wake(for activity: Activity, presence: Presence, at now: Date) -> Date? {
        guard case let .awake(.awaitingResume(_, resumeAt)) = activity, isAway(presence) else { return nil }
        let wake = resumeAt.addingTimeInterval(-wakeLead)
        return wake.timeIntervalSince(now) >= shortestNap ? wake : nil
    }

    /// When an idle user will count as away, if that can still start a nap.
    static func nextCheck(for activity: Activity, presence: Presence, at now: Date) -> Date? {
        guard case .awake(.awaitingResume) = activity, !isAway(presence) else { return nil }
        return now.addingTimeInterval(awayAfter - presence.idleTime)
    }

    private static func isAway(_ presence: Presence) -> Bool {
        presence.isPutAway || presence.idleTime >= awayAfter
    }
}
