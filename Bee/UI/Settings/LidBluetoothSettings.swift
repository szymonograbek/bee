import SwiftUI

/// What happens to Bluetooth with the lid closed, and which devices to disconnect.
struct LidBluetoothSettings: View {
    let bee: BeeController
    /// Nil while loading or when the list couldn't be read.
    @State private var devices: [BluetoothDevice]?

    var body: some View {
        Section {
            Picker(selection: Binding(
                get: { bee.lidBluetooth },
                set: { bee.perform(.setLidBluetooth($0, devices: bee.lidBluetoothDevices)) }
            )) {
                ForEach(LidBluetooth.allCases, id: \.self) { Text($0.title) }
            } label: {
                Text("Bluetooth with the lid closed")
                Text(
                    "Keeps headphones from staying connected to a Mac in your bag. Bee undoes it when you open "
                        + "the lid, and leaves Bluetooth alone while an external display is connected."
                )
            }
            if bee.lidBluetooth == .disconnectChosen {
                if bee.bluetoothPermission.isDenied {
                    LabeledContent {
                        Button("Open Privacy Settings…") { openBluetoothPrivacySettings() }
                    } label: {
                        Text("Needs Bluetooth access")
                        Text("Allow Bee under Bluetooth in Privacy & Security.")
                    }
                }
                deviceList
            }
        }
        .task(id: bee.lidBluetooth) {
            guard bee.lidBluetooth == .disconnectChosen else { return }
            devices = await BluetoothDevices.list()
        }
    }

    @ViewBuilder private var deviceList: some View {
        switch devices {
        case nil:
            Text("Reading paired devices…")
                .foregroundStyle(.secondary)
        case let devices? where devices.isEmpty:
            Text("No paired devices")
                .foregroundStyle(.secondary)
        case let devices?:
            ForEach(devices) { device in
                Toggle(isOn: chosen(device.address)) {
                    Text(device.name)
                    if device.isConnected { Text("Connected") }
                }
            }
        }
    }

    private func chosen(_ address: BluetoothAddress) -> Binding<Bool> {
        Binding(
            get: { bee.lidBluetoothDevices.contains(address) },
            set: { isChosen in
                var chosen = bee.lidBluetoothDevices
                if isChosen { chosen.insert(address) } else { chosen.remove(address) }
                bee.perform(.setLidBluetooth(bee.lidBluetooth, devices: chosen))
            }
        )
    }

    private func openBluetoothPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")
        else { return }
        NSWorkspace.shared.open(url)
    }
}

private extension LidBluetooth {
    var title: String {
        switch self {
        case .leaveOn: "Leave on"
        case .turnOff: "Turn off Bluetooth"
        case .disconnectChosen: "Disconnect chosen devices"
        }
    }
}
