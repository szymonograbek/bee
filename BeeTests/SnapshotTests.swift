import Foundation
import Testing

struct SnapshotTests {
    /// Written by Bee before `keepsAwakeWithLidClosed` existed.
    private let savedBeforeLidSetting = """
        {"schedule":{"isEnabled":true,"rules":[{"weekdays":[6,3,4,2,5],"start":{"hour":8,"minute":0},\
        "end":{"hour":16,"minute":0},"id":"7FADDD78-2023-496F-A32A-53DCEFEFCCBB"}]},\
        "mode":{"automatic":{}},"enabledIntegrations":[],"preventsDisplaySleep":true}
        """

    @Test
    func olderSnapshotKeepsItsSettingsAndLeavesLidSettingOff() throws {
        let defaults = try #require(UserDefaults(suiteName: "SnapshotTests"))
        defer { defaults.removePersistentDomain(forName: "SnapshotTests") }
        defaults.set(Data(savedBeforeLidSetting.utf8), forKey: "bee.snapshot.v1")

        let snapshot = Snapshot.load(from: defaults)

        #expect(snapshot.preventsDisplaySleep)
        #expect(snapshot.enabledIntegrations.isEmpty)
        #expect(!snapshot.keepsAwakeWithLidClosed)
    }

    @Test
    func olderSnapshotWaitsForT3AutoResume() throws {
        let defaults = try #require(UserDefaults(suiteName: "SnapshotTests.autoResume"))
        defer { defaults.removePersistentDomain(forName: "SnapshotTests.autoResume") }
        defaults.set(Data(savedBeforeLidSetting.utf8), forKey: "bee.snapshot.v1")

        #expect(Snapshot.load(from: defaults).keepsAwakeForT3AutoResume)
    }

    @Test
    func lidSettingSurvivesSaveAndLoad() throws {
        let defaults = try #require(UserDefaults(suiteName: "SnapshotTests.roundTrip"))
        defer { defaults.removePersistentDomain(forName: "SnapshotTests.roundTrip") }
        var snapshot = Snapshot.load(from: defaults)
        snapshot.keepsAwakeWithLidClosed = true

        snapshot.save(to: defaults)

        #expect(Snapshot.load(from: defaults) == snapshot)
    }
}
