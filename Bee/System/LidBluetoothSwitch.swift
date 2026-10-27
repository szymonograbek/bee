import Foundation

/// Disconnects the chosen devices that are connected, then reconnects exactly the ones it disconnected. It records
/// them across launches, so a crash still reconnects them on the next start.
@MainActor
final class BluetoothDisconnector {
    private let defaults: UserDefaults
    /// Nil until the first `hold`, so the first one always applies.
    private var requested: Set<BluetoothAddress>?
    private var worker: Task<Void, Never>?

    private static let disconnectedKey = "bee.disconnectedBluetoothDevices"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    private var disconnected: Set<BluetoothAddress> {
        get { Set((defaults.stringArray(forKey: Self.disconnectedKey) ?? []).compactMap(BluetoothAddress.init)) }
        set { defaults.set(newValue.map(\.value).sorted(), forKey: Self.disconnectedKey) }
    }

    /// Idempotent. Empty reconnects every device Bee disconnected. Changes apply one at a time, and only the latest
    /// waiting one runs.
    func hold(disconnecting chosen: Set<BluetoothAddress>) {
        guard chosen != requested else { return }
        requested = chosen
        let previous = worker
        worker = Task {
            await previous?.value
            guard chosen == requested else { return }
            if chosen.isEmpty {
                await reconnect()
            } else {
                await disconnect(chosen)
            }
        }
    }

    private func disconnect(_ chosen: Set<BluetoothAddress>) async {
        guard let devices = await BluetoothDevices.list() else { return }
        for device in devices where device.isConnected && chosen.contains(device.address) {
            // Recorded first, so a crash mid-way still reconnects it.
            disconnected.insert(device.address)
            await BluetoothDevices.disconnect(device.address)
        }
    }

    /// One attempt each. A device that is off or out of range reconnects on its own once it's back.
    private func reconnect() async {
        let addresses = disconnected
        disconnected = []
        for address in addresses {
            await BluetoothDevices.connect(address)
        }
    }
}

/// Applies a `LidBluetooth` choice, to the whole radio or device by device. `.leaveOn` undoes whatever the other
/// choices did, including before a crash.
@MainActor
final class LidBluetoothSwitch {
    private let radio: BluetoothRadio
    private let disconnector: BluetoothDisconnector

    init(defaults: UserDefaults) {
        radio = BluetoothRadio(defaults: defaults)
        disconnector = BluetoothDisconnector(defaults: defaults)
    }

    /// Idempotent. `devices` only apply to `.disconnectChosen`.
    func hold(_ choice: LidBluetooth, devices: Set<BluetoothAddress>) {
        radio.hold(off: choice == .turnOff)
        disconnector.hold(disconnecting: choice == .disconnectChosen ? devices : [])
    }
}
