import Foundation

/// Where T3 Code keeps its data, and what Bee needs to tell T3's own agent sessions apart from the user's.
struct T3Home {
    /// Shared by every T3 Code release channel. The desktop app, its helpers, and its bundled CLI all run
    /// executables inside the app bundle.
    static let bundleIdentifierPrefix = "com.t3tools.t3code"
    /// What T3 Code records as the originator of the Codex sessions it starts.
    static let codexOriginator = "T3 Code"

    let userData: URL

    init(environment: [String: String]) {
        let home = if let custom = environment["T3CODE_HOME"], !custom.isEmpty {
            URL(filePath: custom, directoryHint: .isDirectory)
        } else {
            FileManager.default.homeDirectoryForCurrentUser.appending(path: ".t3", directoryHint: .isDirectory)
        }
        userData = home.appending(path: "userdata", directoryHint: .isDirectory)
    }

    /// The custom home directories T3 runs agents of `driver` (`claudeAgent`, `codex`) with, as written in
    /// its settings, possibly starting with `~`. Missing or unreadable settings mean none.
    func agentHomePaths(driver: String) -> [String] {
        guard let data = try? Data(contentsOf: userData.appending(path: "settings.json")) else { return [] }
        return (try? Self.agentHomePaths(driver: driver, settingsJSON: data)) ?? []
    }

    /// An empty `homePath` means the agent's default home, so it is left out.
    static func agentHomePaths(driver: String, settingsJSON: Data) throws -> [String] {
        let settings = try JSONDecoder().decode(Settings.self, from: settingsJSON)
        return (settings.providerInstances ?? [:]).values
            .filter { $0.driver == driver }
            .compactMap { $0.config?.homePath }
            .filter { !$0.isEmpty }
            .sorted()
    }

    private struct Settings: Decodable {
        let providerInstances: [String: ProviderInstance]?
    }

    private struct ProviderInstance: Decodable {
        let driver: String
        let config: Config?
    }

    private struct Config: Decodable {
        let homePath: String?
    }
}
