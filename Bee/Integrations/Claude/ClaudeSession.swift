import Foundation

/// One file in a Claude Code home's `sessions` directory. Every Claude Code process keeps its own file there
/// up to date, and removes it when it exits cleanly. Pure Foundation so the hostless test bundle can compile it.
struct ClaudeSession: Equatable, Sendable {
    let pid: Int32
    let cwd: String
    /// When Claude Code says its process started, so a crashed session's reused pid isn't taken for it.
    let processStart: Date?
    let status: Status

    enum Status: Equatable, Sendable {
        case busy
        /// Waiting on the user, for example for a permission. `since` is nil when Claude Code doesn't record it.
        case waiting(since: Date?)
        case idle
    }

    /// Mid-turn, or waiting on the user for at most `WaitingOnUser.grace`. A wait of unknown length counts.
    func isWorking(at now: Date) -> Bool {
        switch status {
        case .busy: true
        case let .waiting(since): since.map { WaitingOnUser.keepsAwake(since: $0, at: now) } ?? true
        case .idle: false
        }
    }
}

extension ClaudeSession {
    static func parse(_ data: Data) throws -> Self {
        let file = try JSONDecoder().decode(File.self, from: data)
        let processStart = file.procStart.flatMap { start in
            try? Date(start.split(separator: " ").joined(separator: " "), strategy: processStartFormat)
        }
        return Self(pid: file.pid, cwd: file.cwd, processStart: processStart, status: status(of: file))
    }

    /// An unknown status counts as busy, as it did before Claude Code recorded `waiting`.
    private static func status(of file: File) -> Status {
        switch file.status {
        case "idle": .idle
        case "waiting": .waiting(since: file.statusUpdatedAt.map { Date(timeIntervalSince1970: $0 / 1000) })
        default: .busy
        }
    }

    /// Like `Mon Oct 26 17:54:09 2026`, in UTC.
    private static let processStartFormat = Date.ParseStrategy(
        format: """
            \(weekday: .abbreviated) \(month: .abbreviated) \(day: .defaultDigits) \
            \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\
            \(second: .twoDigits) \(year: .defaultDigits)
            """,
        locale: Locale(identifier: "en_US_POSIX"),
        timeZone: .gmt
    )

    private struct File: Decodable {
        let pid: Int32
        let cwd: String
        let procStart: String?
        /// `busy`, `waiting`, or `idle`.
        let status: String
        /// Milliseconds since 1970.
        let statusUpdatedAt: Double?
    }
}
