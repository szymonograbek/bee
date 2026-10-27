import Foundation

/// Everything Bee remembers across launches, stored as one value under one key.
struct Snapshot: Codable, Equatable {
    var mode: Mode
    var schedule: Schedule
    var enabledIntegrations: Set<IntegrationID>
    var preventsDisplaySleep: Bool
    var keepsAwakeWithLidClosed: Bool
    var lidBluetooth: LidBluetooth
    /// Kept while another `lidBluetooth` is chosen, so switching back restores the choice.
    var lidBluetoothDevices: Set<BluetoothAddress>
    var keepsAwakeForT3AutoResume: Bool
    var sleepsUntilAutoResume: Bool
    var batteryLimit: BatteryLimit

    private static let key = "bee.snapshot.v1"
    private static let firstLaunch = Self(
        mode: .automatic,
        schedule: .workHours,
        enabledIntegrations: Set(IntegrationID.allCases),
        preventsDisplaySleep: false,
        keepsAwakeWithLidClosed: false,
        lidBluetooth: .leaveOn,
        lidBluetoothDevices: [],
        keepsAwakeForT3AutoResume: true,
        sleepsUntilAutoResume: false,
        batteryLimit: .off
    )

    /// A missing or unreadable value falls back to first-launch defaults rather than failing to start.
    static func load(from defaults: UserDefaults) -> Self {
        guard
            let data = defaults.data(forKey: key),
            let snapshot = try? JSONDecoder().decode(Self.self, from: data)
        else { return firstLaunch }
        return snapshot
    }

    func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

/// Decodes snapshots saved before a field existed instead of discarding them for first-launch defaults.
extension Snapshot {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(Mode.self, forKey: .mode)
        schedule = try container.decode(Schedule.self, forKey: .schedule)
        enabledIntegrations = try container.decode(Set<IntegrationID>.self, forKey: .enabledIntegrations)
        preventsDisplaySleep = try container.decode(Bool.self, forKey: .preventsDisplaySleep)
        keepsAwakeWithLidClosed = try container.decodeIfPresent(Bool.self, forKey: .keepsAwakeWithLidClosed) ?? false
        lidBluetooth = try container.decodeIfPresent(LidBluetooth.self, forKey: .lidBluetooth) ?? .leaveOn
        lidBluetoothDevices =
            try container.decodeIfPresent(Set<BluetoothAddress>.self, forKey: .lidBluetoothDevices) ?? []
        keepsAwakeForT3AutoResume = try container.decodeIfPresent(Bool.self, forKey: .keepsAwakeForT3AutoResume) ?? true
        sleepsUntilAutoResume = try container.decodeIfPresent(Bool.self, forKey: .sleepsUntilAutoResume) ?? false
        batteryLimit = try container.decodeIfPresent(BatteryLimit.self, forKey: .batteryLimit) ?? .off
    }
}
