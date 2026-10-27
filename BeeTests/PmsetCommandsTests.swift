import Foundation
import Testing

struct PmsetCommandsTests {
    @Test(arguments: ["szymon", "first.last", "a_b-c9"])
    func acceptsPlainAccountNames(name: String) {
        #expect(SudoersUser(name)?.name == name)
    }

    @Test(arguments: ["", "a b", "x'y", "x\"y", "a;rm", "$(id)", "a\nb", "a\\b"])
    func rejectsNamesThatCouldEscapeTheScript(name: String) {
        #expect(SudoersUser(name) == nil)
    }

    @Test
    func ruleAllowsOnlyDisablingSleepAndSchedulingWakes() throws {
        let user = try #require(SudoersUser("szymon"))
        #expect(
            PmsetCommands.sudoersRule(for: user)
                == "szymon ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0, "
                + "/usr/bin/pmset schedule wake *, /usr/bin/pmset schedule cancel wake *"
        )
    }

    @Test
    func wakeCommandsUsePmsetsLocalTimeFormatAndBeesOwnerName() throws {
        let wake = try date(10, 27, 9, 5)
        let zone = testCalendar.timeZone
        #expect(
            PmsetCommands.scheduleWakeArguments(at: wake, timeZone: zone)
                == ["/usr/bin/pmset", "schedule", "wake", "10/27/26 09:05:00", "Bee"]
        )
        #expect(
            PmsetCommands.cancelWakeArguments(at: wake, timeZone: zone)
                == ["/usr/bin/pmset", "schedule", "cancel", "wake", "10/27/26 09:05:00", "Bee"]
        )
    }

    @Test(arguments: [("1", SystemSleep.disabled), ("0", .allowed)])
    func readsSleepDisabledFromPmset(value: String, expected: SystemSleep) {
        let output = "System-wide power settings:\n SleepDisabled\t\t\(value)\nCurrently in use:\n sleep 1\n"
        #expect(PmsetCommands.systemSleep(fromPmsetOutput: output) == expected)
    }

    @Test(arguments: ["", "Currently in use:\n sleep 1\n", " SleepDisabled\t\tyes\n"])
    func unreadablePmsetOutputIsNil(output: String) {
        #expect(PmsetCommands.systemSleep(fromPmsetOutput: output) == nil)
    }
}
