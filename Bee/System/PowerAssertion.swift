import Foundation
import IOKit.pwr_mgt

/// Holds at most one IOKit power assertion. The OS releases it when the process exits.
@MainActor
final class PowerAssertion {
    enum Kind: Equatable {
        /// The display may sleep; the Mac keeps running.
        case system
        /// The display stays on, which also keeps the Mac running.
        case display
    }

    private var held: (kind: Kind, id: IOPMAssertionID)?

    /// Idempotent. A kind change creates the new assertion before releasing the old, so there is no gap.
    func hold(_ kind: Kind?) {
        guard kind != held?.kind else { return }
        let previous = held
        held = nil
        if let kind, let id = create(kind) {
            held = (kind, id)
        }
        if let previous { IOPMAssertionRelease(previous.id) }
    }

    private func create(_ kind: Kind) -> IOPMAssertionID? {
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            cfString(assertionType(for: kind)),
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            cfString("Bee: keeping your Mac awake"),
            &id
        )
        return result == kIOReturnSuccess ? id : nil
    }

    private func assertionType(for kind: Kind) -> String {
        switch kind {
        case .system: kIOPMAssertionTypePreventUserIdleSystemSleep
        case .display: kIOPMAssertionTypePreventUserIdleDisplaySleep
        }
    }

    /// IOKit takes CFString; this bridges without a type assertion. A nil result makes IOKit return an error.
    private func cfString(_ string: String) -> CFString? {
        CFStringCreateWithCString(kCFAllocatorDefault, string, CFStringBuiltInEncodings.UTF8.rawValue)
    }
}
