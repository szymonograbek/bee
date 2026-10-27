import Foundation
import Observation

/// Whether sudo lets Bee run a set of `pmset` commands without a password. Sudoers is the source of truth, so it is
/// never persisted. Every grant installs the whole rule from `PmsetCommands`, so granting one feature grants all.
@MainActor
@Observable
final class SudoPermission {
    enum State: Equatable {
        case checking
        case installing
        case granted
        case missing
        case failed(String)
    }

    private(set) var state = State.checking

    @ObservationIgnored private let commands: [[String]]

    /// `commands` are the full command lines, as passed to sudo, that the feature needs.
    init(commands: [[String]]) {
        self.commands = commands
    }

    func refresh() async {
        let checked = await Self.check(commands)
        // An install in flight checks again when it finishes.
        guard state != .installing else { return }
        state = checked
    }

    /// Asks for the admin password once if the rule is missing. Returns whether permission is granted.
    func request() async -> Bool {
        switch state {
        case .granted: return true
        case .checking, .installing: return false
        case .missing, .failed: break
        }
        state = .installing
        // Granting another feature may have installed the rule since the last check.
        if await Self.check(commands) == .granted {
            state = .granted
            return true
        }
        let install = await Self.install()
        let checked = await Self.check(commands)
        if case let .failed(message) = install, checked != .granted {
            state = .failed(message)
        } else {
            state = checked
        }
        return checked == .granted
    }

    /// Granted only when sudo allows every command without a password, which also recognizes a rule another app
    /// installed.
    nonisolated private static func check(_ commands: [[String]]) async -> State {
        do throws(ProcessFailure) {
            for command in commands {
                _ = try await ProcessRunner.run(
                    PmsetCommands.sudo,
                    arguments: ["-n", "-l"] + command,
                    timeout: .seconds(5)
                )
            }
            return .granted
        } catch {
            if case .exited = error { return .missing }
            return .failed("Couldn't check the permission: \(error)")
        }
    }

    private enum Install {
        case installed
        case cancelled
        case failed(String)
    }

    nonisolated private static func install() async -> Install {
        guard let user = SudoersUser(NSUserName()) else {
            return .failed("Your account name can't be used in a sudoers rule.")
        }
        do throws(ProcessFailure) {
            _ = try await ProcessRunner.run(
                PmsetCommands.osascript,
                arguments: ["-e", PmsetCommands.installScript(for: user)],
                timeout: .seconds(300)
            )
            return .installed
        } catch {
            guard case let .exited(_, stderr) = error else {
                return .failed("Couldn't install the permission: \(error)")
            }
            // osascript reports a dismissed password prompt as error -128.
            if stderr.contains("-128") { return .cancelled }
            return .failed(stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
