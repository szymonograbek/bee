import Foundation

/// Keeps the Mac awake while any T3 Code thread is running, and optionally while one waits to auto-resume.
struct T3Integration: Integration {
    let id = IntegrationID.t3Code
    let keepsAwakeForAutoResume: Bool
    private let userData: URL

    init(keepsAwakeForAutoResume: Bool, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.keepsAwakeForAutoResume = keepsAwakeForAutoResume
        userData = T3Home(environment: environment).userData
    }

    private static let databaseName = "statev2.sqlite"

    /// T3 has no CLI command that reports activity across projects, so this reads its internal schema.
    /// The run statuses are the set T3 itself indexes as unfinished. A thread hit by a usage limit carries
    /// `limitRecovery`, which stays after the resume, so only reset times at most two minutes old count.
    /// T3 starts the resumed run within seconds of the reset; the margin keeps the Mac awake until it does.
    private static let activityQuery = """
        SELECT count(DISTINCT r.thread_id) AS activeThreads, count(DISTINCT t.project_id) AS activeProjects,
          (SELECT max(unixepoch(json_extract(w.payload_json, '$.limitRecovery.resetAt'), 'subsec'))
            FROM orchestration_v2_projection_threads w
            WHERE w.deleted_at IS NULL AND w.archived_at IS NULL
            AND json_extract(w.payload_json, '$.limitRecovery.autoResume') = 1
            AND unixepoch(json_extract(w.payload_json, '$.limitRecovery.resetAt'), 'subsec')
              > unixepoch('now', '-2 minutes')) AS resumeAt
        FROM orchestration_v2_projection_runs r
        JOIN orchestration_v2_projection_threads t ON t.thread_id = r.thread_id
        WHERE r.status IN ('queued', 'preparing', 'starting', 'running', 'waiting')
        AND t.deleted_at IS NULL AND t.archived_at IS NULL
        """

    func read() async -> IntegrationReading {
        let database = userData.appending(path: Self.databaseName)
        do {
            let output = try await ProcessRunner.run(
                URL(filePath: "/usr/bin/sqlite3"),
                arguments: ["-readonly", "-json", database.path(percentEncoded: false), Self.activityQuery],
                timeout: .seconds(10)
            )
            return try T3Activity.parse(sqliteJSON: output).reading(keepsAwakeForAutoResume: keepsAwakeForAutoResume)
        } catch {
            return .unavailable(reason: "Couldn't read T3 Code's state")
        }
    }

    /// Every T3 state change commits to the database, landing in its write-ahead log first.
    /// The shared-memory index is left out because Bee's own reads touch it.
    func changes() -> AsyncStream<Void> {
        let fileNames: Set = [Self.databaseName, "\(Self.databaseName)-wal"]
        return FileWatcher.changes(
            in: [userData],
            where: { fileNames.contains($0.lastPathComponent) },
            latency: .seconds(1)
        )
    }
}
