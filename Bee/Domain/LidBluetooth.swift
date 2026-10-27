import Foundation

/// What Bee does to Bluetooth while the Mac is put away (`Presence.isPutAway`), undone when it no longer is.
enum LidBluetooth: String, Codable, CaseIterable, Sendable {
    case leaveOn
    case turnOff
    /// Disconnects the devices the user chose, then reconnects the ones Bee disconnected.
    case disconnectChosen
}

/// A Bluetooth device address as `aa:bb:cc:dd:ee:ff`. IOBluetooth writes addresses with dashes, and
/// `system_profiler` in upper case, so both normalize to this.
struct BluetoothAddress: Hashable, Sendable {
    let value: String

    init?(_ text: String) {
        let normalized = text.lowercased().replacing("-", with: ":")
        guard normalized.wholeMatch(of: /[0-9a-f]{2}(:[0-9a-f]{2}){5}/) != nil else { return nil }
        value = normalized
    }
}

extension BluetoothAddress: Codable {
    init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let address = Self(text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not an address"))
        }
        self = address
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

/// A paired device, as `system_profiler SPBluetoothDataType -json` reports it.
struct BluetoothDevice: Equatable, Identifiable, Sendable {
    let address: BluetoothAddress
    let name: String
    let isConnected: Bool

    var id: BluetoothAddress { address }

    /// Connected devices first, then by name. A device listed twice appears once.
    static func list(fromSystemProfilerJSON data: Data) throws -> [Self] {
        let report = try JSONDecoder().decode(Report.self, from: data)
        var devices: [BluetoothAddress: Self] = [:]
        for controller in report.controllers {
            for (entries, isConnected) in [(controller.connected, true), (controller.notConnected, false)] {
                for (name, entry) in (entries ?? []).flatMap(\.self) {
                    guard let address = BluetoothAddress(entry.address), devices[address] == nil else { continue }
                    devices[address] = Self(address: address, name: name, isConnected: isConnected)
                }
            }
        }
        return devices.values.sorted { ($0.isConnected ? 0 : 1, $0.name) < ($1.isConnected ? 0 : 1, $1.name) }
    }

    private struct Report: Decodable {
        let controllers: [Controller]

        enum CodingKeys: String, CodingKey {
            case controllers = "SPBluetoothDataType"
        }
    }

    /// Each list holds one-key objects mapping a device name to its details.
    private struct Controller: Decodable {
        let connected: [[String: Entry]]?
        let notConnected: [[String: Entry]]?

        enum CodingKeys: String, CodingKey {
            case connected = "device_connected"
            case notConnected = "device_not_connected"
        }
    }

    private struct Entry: Decodable {
        let address: String

        enum CodingKeys: String, CodingKey {
            case address = "device_address"
        }
    }
}
