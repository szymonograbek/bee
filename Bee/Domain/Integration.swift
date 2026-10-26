import Foundation

/// Every integration Bee knows about. Adding one starts here.
enum IntegrationID: String, Codable, CaseIterable, Sendable {
    /// First so that when several are active, the menu credits T3 Code.
    case t3Code
    case claudeCode
    case codex

    var displayName: String {
        switch self {
        case .t3Code: "T3 Code"
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        }
    }
}

/// What an integration reported the last time it was checked.
enum IntegrationReading: Equatable, Sendable {
    /// Nothing that needs the Mac awake.
    case idle
    /// Work in progress; `summary` is shown to the user, e.g. "2 threads running".
    case active(summary: String)
    /// The integration could not be checked; `reason` is shown to the user.
    case unavailable(reason: String)
}

/// The lifecycle of one integration from Bee's point of view.
enum IntegrationState: Equatable, Sendable {
    case disabled
    case checking
    case reported(IntegrationReading)

    var activeSummary: String? {
        guard case let .reported(.active(summary)) = self else { return nil }
        return summary
    }
}

/// A source of "keep awake" demand. Bee reads it on start, after each change it signals, and on a slow
/// fallback timer in case a change goes unsignaled.
protocol Integration: Sendable {
    var id: IntegrationID { get }
    func read() async -> IntegrationReading
    /// Yields when a fresh `read` may give a different answer. Ends when the caller stops iterating.
    func changes() -> AsyncStream<Void>
}
