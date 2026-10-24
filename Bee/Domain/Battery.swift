import Foundation

/// What the Mac runs on, as last read from the system.
struct PowerSource: Equatable, Sendable {
    var isPluggedIn: Bool
    /// Percent. nil without an internal battery.
    var batteryCharge: Int?
}

/// Lets the Mac sleep once the battery runs low, whatever else wants it awake.
struct BatteryLimit: Codable, Equatable, Sendable {
    var isEnabled: Bool
    /// Percent. Keeping awake stops below this charge.
    var minimumCharge: Int
    var ignoresWhilePluggedIn: Bool

    static let off = Self(isEnabled: false, minimumCharge: 20, ignoresWhilePluggedIn: true)

    /// The charge that stops keeping awake, or nil when the limit doesn't apply right now.
    func lowCharge(on power: PowerSource) -> Int? {
        guard isEnabled, let charge = power.batteryCharge, charge < minimumCharge else { return nil }
        if power.isPluggedIn, ignoresWhilePluggedIn { return nil }
        return charge
    }
}
