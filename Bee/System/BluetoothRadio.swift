import Foundation
import IOBluetooth

/// Turns the Bluetooth radio off and back on. The radio's state outlives Bee, so Bee records that it turned the radio
/// off and only turns back on what it turned off, even after a crash.
@MainActor
final class BluetoothRadio {
    private let defaults: UserDefaults
    /// Nil until the first `hold`, so the first one always applies, which turns back on a radio left off by a crash.
    private var requested: Request?

    private enum Request {
        case off
        case restored
    }

    private static let ownershipKey = "bee.ownsBluetoothOff"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    private var ownsRadioOff: Bool {
        get { defaults.bool(forKey: Self.ownershipKey) }
        set { defaults.set(newValue, forKey: Self.ownershipKey) }
    }

    /// Idempotent. Leaves a radio the user turned off alone.
    func hold(off: Bool) {
        let request = off ? Request.off : .restored
        guard request != requested else { return }
        requested = request
        if off {
            guard IOBluetoothPreferenceGetControllerPowerState() == 1 else { return }
            ownsRadioOff = true
            IOBluetoothPreferenceSetControllerPowerState(0)
        } else if ownsRadioOff {
            IOBluetoothPreferenceSetControllerPowerState(1)
            ownsRadioOff = false
        }
    }
}
