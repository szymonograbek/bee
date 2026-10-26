import Foundation

/// Keeps the Mac awake while a Codex session the user started is mid-turn, including while it waits on them.
/// Sessions T3 Code runs are its threads, which the T3 Code integration covers, so they are skipped.
struct CodexIntegration: Integration {
    let id = IntegrationID.codex
    private let sessionDirectories: [URL]

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        sessionDirectories = AgentHomes(
            defaultPath: "~/.codex",
            overrideVariable: "CODEX_HOME",
            t3Driver: "codex",
            environment: environment
        ).directories.map { $0.appending(path: "sessions", directoryHint: .isDirectory) }
    }

    /// Codex keeps a session's rollout open for as long as the session is loaded, so the rollouts open in
    /// running `codex` processes are exactly the live sessions, and a crashed one drops out on its own.
    func read() async -> IntegrationReading {
        guard !sessionDirectories.isEmpty else { return .unavailable(reason: "Codex isn't set up") }
        let prefixes = sessionDirectories.map { $0.path(percentEncoded: false) }
        let rollouts = Set(ProcessTable.pids(named: "codex").flatMap(ProcessTable.openFiles))
            .filter { path in path.hasSuffix(".jsonl") && prefixes.contains { path.hasPrefix($0) } }
        let working = rollouts.sorted().compactMap(Self.workingDirectory(ofRollout:))
        return AgentActivity(workingDirectories: working).reading
    }

    /// Codex appends to the rollout as a turn starts and ends.
    func changes() -> AsyncStream<Void> {
        FileWatcher.changes(
            in: sessionDirectories,
            where: { $0.pathExtension == "jsonl" },
            latency: .milliseconds(500)
        )
    }

    /// The session's working directory if it is mid-turn and not T3 Code's.
    private static func workingDirectory(ofRollout path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        guard let meta = try? CodexRollout.meta(firstLine: firstLine(of: handle)),
              meta.originator != T3Home.codexOriginator,
              latestTurn(in: handle) == .inProgress
        else { return nil }
        return meta.cwd
    }

    private static func firstLine(of handle: FileHandle) throws -> Data {
        // The metadata line embeds the base instructions, so it can run to tens of kilobytes.
        var line = Data()
        try handle.seek(toOffset: 0)
        while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
            if let newline = chunk.firstIndex(of: UInt8(ascii: "\n")) {
                return line + chunk[..<newline]
            }
            line += chunk
        }
        return line
    }

    /// Reads only the end of the file unless the latest turn boundary lies further back.
    private static func latestTurn(in handle: FileHandle) -> CodexRollout.Turn? {
        let tailLength: UInt64 = 256 * 1024
        guard let size = try? handle.seekToEnd() else { return nil }
        if size > tailLength,
           (try? handle.seek(toOffset: size - tailLength)) != nil,
           let tail = try? handle.readToEnd(),
           let turn = CodexRollout.latestTurn(in: tail) {
            return turn
        }
        guard (try? handle.seek(toOffset: 0)) != nil, let whole = try? handle.readToEnd() else { return nil }
        return CodexRollout.latestTurn(in: whole)
    }
}
