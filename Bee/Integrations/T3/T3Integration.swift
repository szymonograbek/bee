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
    /// A run waiting on the user stays `running` with a pending runtime request; one pending longer than
    /// `WaitingOnUser.grace` stops counting. A `waiting` run is draining background work after its turn, so it counts.
    /// A thread whose run has ended can still wait on background work its agent started. That counts by T3's own
    /// rule for showing it as waiting: any awaited task, or any subagent or background task. A native subagent
    /// can outlive both, so a thread with an unfinished subagent counts too.
    private static let activityQuery = """
        WITH working AS (
          SELECT r.thread_id FROM orchestration_v2_projection_runs r
          WHERE r.status IN ('queued', 'preparing', 'starting', 'running', 'waiting')
          AND NOT EXISTS (SELECT 1 FROM orchestration_v2_projection_runtime_requests q
            WHERE q.thread_id = r.thread_id AND q.status = 'pending'
            AND unixepoch(q.created_at) <= unixepoch('now', '-\(Int(WaitingOnUser.grace)) seconds'))
          UNION
          SELECT p.thread_id
          FROM orchestration_v2_projection_provider_threads p,
            json_each(p.payload_json, '$.pendingBackgroundTasks') task
          WHERE json_extract(task.value, '$.awaited') = 1
          OR json_extract(task.value, '$.kind') IN ('subagent', 'background_task')
          UNION
          SELECT s.thread_id FROM orchestration_v2_projection_subagents s
          WHERE s.status IN ('pending', 'running'))
        SELECT count(DISTINCT t.thread_id) AS activeThreads, count(DISTINCT t.project_id) AS activeProjects,
          (SELECT max(unixepoch(json_extract(w.payload_json, '$.limitRecovery.resetAt'), 'subsec'))
            FROM orchestration_v2_projection_threads w
            WHERE w.deleted_at IS NULL AND w.archived_at IS NULL
            AND json_extract(w.payload_json, '$.limitRecovery.autoResume') = 1
            AND unixepoch(json_extract(w.payload_json, '$.limitRecovery.resetAt'), 'subsec')
              > unixepoch('now', '-2 minutes')) AS resumeAt
        FROM working
        JOIN orchestration_v2_projection_threads t ON t.thread_id = working.thread_id
        WHERE t.deleted_at IS NULL AND t.archived_at IS NULL
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
