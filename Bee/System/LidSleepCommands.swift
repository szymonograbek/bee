import Foundation

/// The system-wide `SleepDisabled` setting `pmset` reports.
enum SystemSleep: Equatable {
    case allowed
    case disabled
}

/// A macOS account name limited to characters that cannot break out of the shell and AppleScript strings
/// the sudoers rule is written through.
struct SudoersUser: Equatable {
    let name: String

    init?(_ name: String) {
        guard name.wholeMatch(of: /[A-Za-z0-9._-]+/) != nil else { return nil }
        self.name = name
    }
}

/// The `pmset disablesleep` command lines Bee runs through sudo, and the sudoers rule that allows exactly those.
/// Free of side effects so the tests can compile it.
enum LidSleepCommands {
    static let sudo = URL(filePath: "/usr/bin/sudo")
    static let pmset = URL(filePath: "/usr/bin/pmset")
    static let osascript = URL(filePath: "/usr/bin/osascript")
    static let sudoersPath = "/etc/sudoers.d/bee"

    static func pmsetArguments(for sleep: SystemSleep) -> [String] {
        [pmset.path(percentEncoded: false), "-a", "disablesleep", sleep == .disabled ? "1" : "0"]
    }

    /// Reads `SleepDisabled` from `pmset -g`. Nil when the line is missing or not 0 or 1.
    static func systemSleep(fromPmsetOutput output: String) -> SystemSleep? {
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.first == "SleepDisabled", fields.count == 2 else { continue }
            switch fields[1] {
            case "1": return .disabled
            case "0": return .allowed
            default: return nil
            }
        }
        return nil
    }

    static func sudoersRule(for user: SudoersUser) -> String {
        let commands = [SystemSleep.disabled, .allowed].map { pmsetArguments(for: $0).joined(separator: " ") }
        return "\(user.name) ALL=(root) NOPASSWD: \(commands.joined(separator: ", "))"
    }

    /// AppleScript that asks for an admin password once, then installs the rule only if `visudo` accepts it,
    /// so a bad rule can never lock the user out of sudo. Uses no double quotes or backslashes inside the
    /// AppleScript string literal.
    static func installScript(for user: SudoersUser) -> String {
        let shell = [
            "t=$(/usr/bin/mktemp)",
            "/bin/echo '\(sudoersRule(for: user))' > $t",
            "/usr/sbin/visudo -cf $t",
            "/usr/bin/install -m 0440 -o root -g wheel $t \(sudoersPath)"
        ].joined(separator: " && ") + "; s=$?; /bin/rm -f $t; exit $s"
        return "do shell script \"\(shell)\" with administrator privileges"
    }
}
