import Foundation

/// Keeps the Mac awake while any T3 Code thread is running.
struct T3Integration: Integration {
    let id = IntegrationID.t3Code
    let home: URL

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        if let custom = environment["T3CODE_HOME"], !custom.isEmpty {
            home = URL(filePath: custom, directoryHint: .isDirectory)
        } else {
            home = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".t3", directoryHint: .isDirectory)
        }
    }

    private static let maxConcurrentProjects = 4

    /// Only projects with thread activity in the last day, so each poll launches a handful of CLI processes
    /// instead of one per project ever opened. T3 has no CLI command that lists projects.
    private static let recentProjectsQuery = """
        SELECT p.project_id AS id, p.title AS title FROM projection_projects p \
        WHERE p.deleted_at IS NULL AND EXISTS (SELECT 1 FROM orchestration_v2_projection_threads t \
        WHERE t.project_id = p.project_id AND t.deleted_at IS NULL AND t.archived_at IS NULL \
        AND t.updated_at > strftime('%Y-%m-%dT%H:%M:%fZ', 'now', '-1 day'))
        """

    func read() async -> IntegrationReading {
        guard let cli = locateCLI() else {
            return .unavailable(reason: "T3 Code CLI not found")
        }
        guard let projects = await recentProjects() else {
            return .unavailable(reason: "Couldn't read T3 projects")
        }
        let outcomes = await withTaskGroup(of: T3ProjectOutcome.self) { group in
            var pending = projects[...]
            var outcomes: [T3ProjectOutcome] = []
            for _ in 0..<Self.maxConcurrentProjects {
                guard let project = pending.popFirst() else { break }
                group.addTask { await Self.check(project, cli: cli) }
            }
            for await outcome in group {
                outcomes.append(outcome)
                if let project = pending.popFirst() {
                    group.addTask { await Self.check(project, cli: cli) }
                }
            }
            return outcomes
        }
        return T3ThreadList.reading(from: outcomes)
    }

    private func locateCLI() -> URL? {
        let candidates = [
            home.appending(path: "bin/t3"),
            URL(filePath: "/opt/homebrew/bin/t3"),
            URL(filePath: "/usr/local/bin/t3")
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path(percentEncoded: false)) }
    }

    private func recentProjects() async -> [T3Project]? {
        let database = home.appending(path: "userdata/statev2.sqlite")
        do {
            let output = try await ProcessRunner.run(
                URL(filePath: "/usr/bin/sqlite3"),
                arguments: ["-readonly", "-json", database.path(percentEncoded: false), Self.recentProjectsQuery],
                timeout: .seconds(10)
            )
            return try T3ThreadList.projects(fromSQLiteJSON: output)
        } catch {
            return nil
        }
    }

    private static func check(_ project: T3Project, cli: URL) async -> T3ProjectOutcome {
        do {
            let output = try await ProcessRunner.run(
                cli,
                arguments: ["thread", "list", "--project", project.id, "--json"],
                timeout: .seconds(15)
            )
            return .checked(project, runningThreads: try T3ThreadList.runningCount(fromThreadListJSON: output))
        } catch {
            return .failed(project, reason: String(describing: error))
        }
    }
}
