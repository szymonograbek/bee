import Foundation

/// The data directories one agent CLI uses on this Mac.
struct AgentHomes {
    /// Existing directories only, with symlinks resolved, so paths match what the kernel reports for open files.
    let directories: [URL]

    /// Candidates are `overrideVariable` (or `defaultPath` when unset) plus every custom home T3 Code runs agents
    /// of `t3Driver` with. A user running the CLI by hand usually shares one of those homes, and Bee, launched
    /// from the Dock rather than a shell, can't see the shell's environment.
    init(defaultPath: String, overrideVariable: String, t3Driver: String, environment: [String: String]) {
        let override = environment[overrideVariable].flatMap { $0.isEmpty ? nil : $0 }
        let paths = [override ?? defaultPath] + T3Home(environment: environment).agentHomePaths(driver: t3Driver)
        var seen = Set<String>()
        directories = paths
            .map { Self.expandingTilde($0).resolvingSymlinksInPath() }
            .filter { url in
                var isDirectory: ObjCBool = false
                let path = url.path(percentEncoded: false)
                return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
            }
            .filter { seen.insert($0.path(percentEncoded: false)).inserted }
    }

    private static func expandingTilde(_ path: String) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        if path == "~" { return home }
        if path.hasPrefix("~/") { return home.appending(path: String(path.dropFirst(2)), directoryHint: .isDirectory) }
        return URL(filePath: path, directoryHint: .isDirectory)
    }
}
