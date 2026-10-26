import Foundation

/// One file in a Claude Code home's `sessions` directory. Every Claude Code process keeps its own file there
/// up to date, and removes it when it exits cleanly. Pure Foundation so the hostless test bundle can compile it.
struct ClaudeSession: Equatable, Sendable {
    let pid: Int32
    let cwd: String
    /// When Claude Code says its process started, so a crashed session's reused pid isn't taken for it.
    let processStart: Date?
    /// Mid-turn, or waiting on the user, for example for a permission.
    let isWorking: Bool
}

extension ClaudeSession {
    static func parse(_ data: Data) throws -> Self {
        let file = try JSONDecoder().decode(File.self, from: data)
        let processStart = file.procStart.flatMap { start in
            try? Date(start.split(separator: " ").joined(separator: " "), strategy: processStartFormat)
        }
        return Self(pid: file.pid, cwd: file.cwd, processStart: processStart, isWorking: file.status != "idle")
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
    }
}
