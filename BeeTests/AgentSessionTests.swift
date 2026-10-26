import Foundation
import Testing

struct AgentSessionTests {
    // MARK: Summary

    @Test
    func noSessionsIsIdle() {
        #expect(AgentActivity(workingDirectories: []).reading == .idle)
    }

    @Test
    func sessionsInOneProject() {
        #expect(AgentActivity(workingDirectories: ["/a"]).reading == .active(summary: "1 session running"))
        #expect(AgentActivity(workingDirectories: ["/a", "/a"]).reading == .active(summary: "2 sessions running"))
    }

    @Test
    func sessionsAcrossProjects() {
        #expect(
            AgentActivity(workingDirectories: ["/a", "/b", "/a"]).reading
                == .active(summary: "3 sessions running in 2 projects")
        )
    }

    // MARK: Claude Code session files

    @Test(arguments: [("busy", true), ("waiting", true), ("idle", false)])
    func claudeStatus(status: String, isWorking: Bool) throws {
        let file = #"{"pid":63108,"cwd":"/repo","procStart":"Mon Oct 26 17:54:09 2026","status":"\#(status)"}"#
        #expect(
            try ClaudeSession.parse(Data(file.utf8)) == ClaudeSession(
                pid: 63108,
                cwd: "/repo",
                processStart: Date(timeIntervalSince1970: 1_793_037_249),
                isWorking: isWorking
            )
        )
    }

    @Test
    func claudeSingleDigitDayIsPadded() throws {
        let file = #"{"pid":1,"cwd":"/","procStart":"Tue Oct  6 08:00:00 2026","status":"idle"}"#
        #expect(try ClaudeSession.parse(Data(file.utf8)).processStart == Date(timeIntervalSince1970: 1_791_273_600))
    }

    @Test
    func claudeMissingProcessStart() throws {
        let file = #"{"pid":1,"cwd":"/","status":"busy"}"#
        #expect(try ClaudeSession.parse(Data(file.utf8)).processStart == nil)
    }

    @Test(arguments: ["", "{}", #"{"pid":1,"cwd":"/"}"#])
    func malformedClaudeFileThrows(file: String) {
        #expect(throws: (any Error).self) { try ClaudeSession.parse(Data(file.utf8)) }
    }

    // MARK: Codex rollouts

    @Test
    func codexMeta() throws {
        let line = #"{"type":"session_meta","payload":{"cwd":"/repo","originator":"T3 Code","source":"vscode"}}"#
        #expect(
            try CodexRollout.meta(firstLine: Data(line.utf8)) == CodexRollout.Meta(originator: "T3 Code", cwd: "/repo")
        )
    }

    @Test
    func codexFirstLineMustBeMeta() {
        let line = #"{"type":"event_msg","payload":{"type":"task_started"}}"#
        #expect(throws: (any Error).self) { try CodexRollout.meta(firstLine: Data(line.utf8)) }
    }

    @Test(arguments: [
        ("task_started", CodexRollout.Turn.inProgress),
        ("task_complete", .finished),
        ("turn_aborted", .finished)
    ])
    func codexLatestBoundaryWins(last: String, turn: CodexRollout.Turn) {
        let text = """
            {"type":"event_msg","payload":{"type":"task_started"}}
            {"type":"event_msg","payload":{"type":"task_complete"}}
            {"type":"event_msg","payload":{"type":"\(last)"}}
            {"type":"response_item","payload":{"type":"message","text":"task_started"}}
            {"type":"event_msg","payload":{"type":"token_count"}}
            """
        #expect(CodexRollout.latestTurn(in: Data(text.utf8)) == turn)
    }

    @Test
    func codexTailStartingMidLine() {
        let text = #"ad":"task_complete"}}"# + "\n" + #"{"type":"event_msg","payload":{"type":"task_started"}}"#
        #expect(CodexRollout.latestTurn(in: Data(text.utf8)) == .inProgress)
    }

    @Test
    func codexNoBoundary() {
        let text = #"{"type":"event_msg","payload":{"type":"token_count"}}"#
        #expect(CodexRollout.latestTurn(in: Data(text.utf8)) == nil)
    }

    // MARK: T3 Code settings

    @Test
    func t3AgentHomesForDriver() throws {
        let settings = """
            {"providerInstances":{
              "claudeAgent":{"driver":"claudeAgent","config":{"homePath":"~/.claude"}},
              "work":{"driver":"claudeAgent","config":{"homePath":"~/.claude-work"}},
              "blank":{"driver":"claudeAgent","config":{"homePath":""}},
              "bare":{"driver":"claudeAgent"},
              "codex":{"driver":"codex","config":{"homePath":"/opt/codex"}}
            }}
            """
        #expect(
            try T3Home.agentHomePaths(driver: "claudeAgent", settingsJSON: Data(settings.utf8))
                == ["~/.claude", "~/.claude-work"]
        )
        #expect(try T3Home.agentHomePaths(driver: "codex", settingsJSON: Data(settings.utf8)) == ["/opt/codex"])
    }

    @Test
    func t3SettingsWithoutProviders() throws {
        #expect(try T3Home.agentHomePaths(driver: "codex", settingsJSON: Data("{}".utf8)).isEmpty)
    }
}
