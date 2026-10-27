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

/// The `pmset` command lines Bee runs through sudo, and the sudoers rule that allows exactly those.
/// Free of side effects so the tests can compile it.
enum PmsetCommands {
    static let sudo = URL(filePath: "/usr/bin/sudo")
    static let pmset = URL(filePath: "/usr/bin/pmset")
    static let osascript = URL(filePath: "/usr/bin/osascript")
    static let sudoersPath = "/etc/sudoers.d/bee"

    static func pmsetArguments(for sleep: SystemSleep) -> [String] {
        [pmset.path(percentEncoded: false), "-a", "disablesleep", sleep == .disabled ? "1" : "0"]
    }

    /// Bee owns the wakes it schedules, so it cancels only its own.
    static func scheduleWakeArguments(at date: Date, timeZone: TimeZone = .current) -> [String] {
        [pmset.path(percentEncoded: false), "schedule", "wake", wakeTime(date, timeZone), wakeOwner]
    }

    static func cancelWakeArguments(at date: Date, timeZone: TimeZone = .current) -> [String] {
        [pmset.path(percentEncoded: false), "schedule", "cancel", "wake", wakeTime(date, timeZone), wakeOwner]
    }

    /// Needs no root.
    static let sleepNowArguments = ["sleepnow"]

    private static let wakeOwner = "Bee"

    /// `pmset` takes local time as `MM/dd/yy HH:mm:ss`.
    private static func wakeTime(_ date: Date, _ timeZone: TimeZone) -> String {
        var style = Date.VerbatimFormatStyle(
            format: """
                \(month: .twoDigits)/\(day: .twoDigits)/\(year: .twoDigits) \
                \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\
                \(second: .twoDigits)
                """,
            timeZone: timeZone,
            calendar: Calendar(identifier: .gregorian)
        )
        style.locale = Locale(identifier: "en_US_POSIX")
        return date.formatted(style)
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

    /// The wake commands end in a wildcard because their time changes. `pmset schedule` can only add or cancel
    /// wakes.
    static func sudoersRule(for user: SudoersUser) -> String {
        let sleepCommands = [SystemSleep.disabled, .allowed].map { pmsetArguments(for: $0).joined(separator: " ") }
        let wakeCommands = ["schedule wake *", "schedule cancel wake *"].map {
            "\(pmset.path(percentEncoded: false)) \($0)"
        }
        return "\(user.name) ALL=(root) NOPASSWD: \((sleepCommands + wakeCommands).joined(separator: ", "))"
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
