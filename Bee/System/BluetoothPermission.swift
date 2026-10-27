import CoreBluetooth
import Observation

/// Bluetooth access, which disconnecting devices needs. macOS only asks through CoreBluetooth, so `request` starts a
/// central manager just to show the prompt while the user is in Settings, not when the lid closes.
@MainActor
@Observable
final class BluetoothPermission: NSObject, CBCentralManagerDelegate {
    private(set) var isDenied = BluetoothPermission.readDenied()

    @ObservationIgnored private var prompt: CBCentralManager?

    func request() {
        isDenied = Self.readDenied()
        guard CBManager.authorization == .notDetermined, prompt == nil else { return }
        prompt = CBCentralManager(delegate: self, queue: .main)
    }

    /// Called on the main queue once the user answers.
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            isDenied = Self.readDenied()
            prompt = nil
        }
    }

    private static func readDenied() -> Bool {
        switch CBManager.authorization {
        case .denied, .restricted: true
        case .allowedAlways, .notDetermined: false
        @unknown default: false
        }
    }
}
