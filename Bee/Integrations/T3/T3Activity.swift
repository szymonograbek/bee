import Foundation

/// What T3 Code is doing right now, as read from its local database.
/// Pure Foundation so the hostless test bundle can compile it.
struct T3Activity: Equatable, Sendable {
    /// Threads with a run in progress, including runs waiting on the user.
    var activeThreads: Int
    var activeProjects: Int
    /// When the latest thread armed to auto-resume after a usage limit will resume, if any.
    var resumeAt: Date?
}

extension T3Activity {
    /// Parses the one row of `sqlite3 -json` output from `T3Integration`'s activity query.
    static func parse(sqliteJSON data: Data) throws -> Self {
        guard let row = try JSONDecoder().decode([Row].self, from: data).first else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Activity query returned no row"))
        }
        return Self(
            activeThreads: row.activeThreads,
            activeProjects: row.activeProjects,
            resumeAt: row.resumeAt.map(Date.init(timeIntervalSince1970:))
        )
    }

    /// Running work wins over a pending auto-resume, which counts only when the user opted in.
    func reading(keepsAwakeForAutoResume: Bool) -> IntegrationReading {
        if activeThreads > 0 {
            let threadText = activeThreads == 1 ? "1 thread running" : "\(activeThreads) threads running"
            return .active(summary: activeProjects > 1 ? "\(threadText) in \(activeProjects) projects" : threadText)
        }
        if keepsAwakeForAutoResume, let resumeAt {
            return .active(summary: "Auto-resuming at \(resumeAt.formatted(date: .omitted, time: .shortened))")
        }
        return .idle
    }

    private struct Row: Decodable {
        let activeThreads: Int
        let activeProjects: Int
        let resumeAt: Double?
    }
}
