import Foundation
import IOBluetooth

/// Lists paired Bluetooth devices and connects or disconnects one. IOBluetooth's own `isConnected` reports every
/// device as disconnected, so the list comes from `system_profiler`, which also needs no Bluetooth permission.
enum BluetoothDevices {
    /// Nil when `system_profiler` fails.
    static func list() async -> [BluetoothDevice]? {
        guard let output = try? await ProcessRunner.run(
            URL(filePath: "/usr/sbin/system_profiler"),
            arguments: ["SPBluetoothDataType", "-json"],
            timeout: .seconds(10)
        ) else { return nil }
        return try? BluetoothDevice.list(fromSystemProfilerJSON: output)
    }

    static func disconnect(_ address: BluetoothAddress) async {
        _ = device(address)?.closeConnection()
    }

    /// Blocks for up to the page timeout, several seconds, when the device is out of range, so it runs off the main
    /// actor.
    static func connect(_ address: BluetoothAddress) async {
        _ = device(address)?.openConnection()
    }

    private static func device(_ address: BluetoothAddress) -> IOBluetoothDevice? {
        IOBluetoothDevice(addressString: address.value.replacing(":", with: "-"))
    }
}
