import Foundation

/// Keeps the Mac awake while a Claude Code session the user started is working or waiting on them.
/// Sessions T3 Code runs are its threads, which the T3 Code integration covers, so they are skipped.
struct ClaudeIntegration: Integration {
    let id = IntegrationID.claudeCode
    private let sessionDirectories: [URL]

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        sessionDirectories = AgentHomes(
            defaultPath: "~/.claude",
            overrideVariable: "CLAUDE_CONFIG_DIR",
            t3Driver: "claudeAgent",
            environment: environment
        ).directories.map { $0.appending(path: "sessions", directoryHint: .isDirectory) }
    }

    func read() async -> IntegrationReading {
        guard !sessionDirectories.isEmpty else { return .unavailable(reason: "Claude Code isn't set up") }
        let files = sessionDirectories.flatMap { directory in
            let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            return (contents ?? []).filter(Self.isSessionFile)
        }
        let sessions = files.compactMap { file in
            (try? Data(contentsOf: file)).flatMap { try? ClaudeSession.parse($0) }
        }
        let working = sessions.filter { $0.isWorking && Self.isLive($0) && !Self.isRunByT3($0) }
        return AgentActivity(workingDirectories: working.map(\.cwd)).reading
    }

    /// Claude Code rewrites its session file whenever its status changes.
    func changes() -> AsyncStream<Void> {
        FileWatcher.changes(in: sessionDirectories, where: Self.isSessionFile, latency: .milliseconds(500))
    }

    @Sendable
    private static func isSessionFile(_ url: URL) -> Bool {
        url.pathExtension == "json"
    }

    /// A crashed session leaves its file behind.
    private static func isLive(_ session: ClaudeSession) -> Bool {
        guard let started = ProcessTable.startTime(of: session.pid) else { return false }
        guard let recorded = session.processStart else { return true }
        return abs(started.timeIntervalSince(recorded)) < 1
    }

    /// T3 Code spawns Claude Code directly. Only the direct parent counts, so `claude` typed into a terminal
    /// inside T3 Code still counts as the user's own.
    private static func isRunByT3(_ session: ClaudeSession) -> Bool {
        guard let parent = ProcessTable.parent(of: session.pid),
              let bundleIdentifier = ProcessTable.appBundleIdentifier(of: parent)
        else { return false }
        return bundleIdentifier.hasPrefix(T3Home.bundleIdentifierPrefix)
    }
}
