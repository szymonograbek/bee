/// Agent CLI sessions found working outside T3 Code, each identified by its working directory.
/// Pure so the hostless test bundle can compile it.
struct AgentActivity: Equatable, Sendable {
    /// One entry per session that is mid-turn or waiting on the user.
    var workingDirectories: [String]

    var reading: IntegrationReading {
        let sessions = workingDirectories.count
        guard sessions > 0 else { return .idle }
        let sessionText = sessions == 1 ? "1 session running" : "\(sessions) sessions running"
        let projects = Set(workingDirectories).count
        return .active(summary: projects > 1 ? "\(sessionText) in \(projects) projects" : sessionText)
    }
}
