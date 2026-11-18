import Foundation
import Observation

/// How to tell whether sudo runs a feature's commands without a password.
enum SudoCheck {
    /// Asks sudo whether it allows each full command line. sudo can't say whether a password is needed, so a rule
    /// that needs one, such as an admin's `ALL`, also passes. For commands that have no harmless form to run.
    case allows([[String]])
    /// Runs a command that changes nothing and sees whether sudo asks for a password.
    case runs([String])
}

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

    @ObservationIgnored private let check: SudoCheck

    init(check: SudoCheck) {
        self.check = check
    }

    func refresh() async {
        let checked = await Self.check(check)
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
        if await Self.check(check) == .granted {
            state = .granted
            return true
        }
        let install = await Self.install()
        let checked = await Self.check(check)
        if case let .failed(message) = install, checked != .granted {
            state = .failed(message)
        } else {
            state = checked
        }
        return checked == .granted
    }

    /// Also recognizes a rule another app installed.
    nonisolated private static func check(_ check: SudoCheck) async -> State {
        do throws(ProcessFailure) {
            switch check {
            case let .allows(commands):
                for command in commands {
                    _ = try await sudo(["-l"] + command)
                }
            case let .runs(command):
                _ = try await sudo(command)
            }
            return .granted
        } catch {
            guard case let .exited(_, stderr) = error else { return .failed("Couldn't check the permission: \(error)") }
            switch check {
            case .allows:
                return .missing
            case .runs:
                // sudo -n refuses with this when the command would need a password, including when no rule allows
                // it. Any other failure came from the command itself, which sudo let run.
                return stderr.contains("a password is required") ? .missing : .granted
            }
        }
    }

    nonisolated private static func sudo(_ arguments: [String]) async throws(ProcessFailure) -> Data {
        try await ProcessRunner.run(PmsetCommands.sudo, arguments: ["-n"] + arguments, timeout: .seconds(5))
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
