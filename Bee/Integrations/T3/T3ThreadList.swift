import Foundation

struct T3Project: Decodable, Equatable, Sendable {
    let id: String
    let title: String
}

/// What happened when one project's threads were checked.
enum T3ProjectOutcome: Equatable, Sendable {
    case checked(T3Project, runningThreads: Int)
    case failed(T3Project, reason: String)
}

/// Every T3 wire format Bee reads, and the policy that turns a poll into a reading.
/// Pure Foundation so the hostless test bundle can compile it.
enum T3ThreadList {
    /// Parses `sqlite3 -json` output. sqlite3 prints nothing at all when the query matches no rows.
    static func projects(fromSQLiteJSON data: Data) throws -> [T3Project] {
        if String(bytes: data, encoding: .utf8)?.allSatisfy(\.isWhitespace) == true { return [] }
        return try JSONDecoder().decode([T3Project].self, from: data)
    }

    /// Parses `t3 thread list --json`. Only `status` is read, so unrelated field changes can't break Bee.
    static func runningCount(fromThreadListJSON data: Data) throws -> Int {
        try JSONDecoder().decode([ThreadStatus].self, from: data)
            .count { $0.status == "running" }
    }

    /// Running work wins even when some projects failed; idle is claimed only when every project was read.
    static func reading(from outcomes: [T3ProjectOutcome]) -> IntegrationReading {
        var running: [Int] = []
        var failures = 0
        for outcome in outcomes {
            switch outcome {
            case let .checked(_, runningThreads) where runningThreads > 0:
                running.append(runningThreads)
            case .checked:
                break
            case .failed:
                failures += 1
            }
        }
        if !running.isEmpty {
            return .active(summary: summary(threads: running.reduce(0, +), projects: running.count))
        }
        if failures == 0 {
            return .idle
        }
        return .unavailable(reason: "Couldn't read \(failures) of \(outcomes.count) projects")
    }

    private static func summary(threads: Int, projects: Int) -> String {
        let threadText = threads == 1 ? "1 thread running" : "\(threads) threads running"
        return projects > 1 ? "\(threadText) in \(projects) projects" : threadText
    }

    private struct ThreadStatus: Decodable {
        let status: String
    }
}
