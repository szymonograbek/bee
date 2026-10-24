import Testing

struct LidSleepCommandsTests {
    @Test(arguments: ["szymon", "first.last", "a_b-c9"])
    func acceptsPlainAccountNames(name: String) {
        #expect(SudoersUser(name)?.name == name)
    }

    @Test(arguments: ["", "a b", "x'y", "x\"y", "a;rm", "$(id)", "a\nb", "a\\b"])
    func rejectsNamesThatCouldEscapeTheScript(name: String) {
        #expect(SudoersUser(name) == nil)
    }

    @Test
    func ruleAllowsExactlyTheTwoPmsetCommands() throws {
        let user = try #require(SudoersUser("szymon"))
        #expect(
            LidSleepCommands.sudoersRule(for: user)
                == "szymon ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"
        )
    }

    @Test(arguments: [("1", SystemSleep.disabled), ("0", .allowed)])
    func readsSleepDisabledFromPmset(value: String, expected: SystemSleep) {
        let output = "System-wide power settings:\n SleepDisabled\t\t\(value)\nCurrently in use:\n sleep 1\n"
        #expect(LidSleepCommands.systemSleep(fromPmsetOutput: output) == expected)
    }

    @Test(arguments: ["", "Currently in use:\n sleep 1\n", " SleepDisabled\t\tyes\n"])
    func unreadablePmsetOutputIsNil(output: String) {
        #expect(LidSleepCommands.systemSleep(fromPmsetOutput: output) == nil)
    }
}
