import AppKit
import IOKit

/// `kIOPMMessageClamshellStateChange`, a C macro Swift doesn't import. Global so the C callback can read it.
private let clamshellStateChange: UInt32 = 0xE003_4100

/// Reads whether someone is at the Mac. `lidChanges` reports the lid; display changes arrive as
/// `NSApplication.didChangeScreenParametersNotification`.
@MainActor
final class PresenceMonitor {
    /// Waking the Mac or opening its lid shows someone is there, though neither counts as input.
    private var lastArrival = Date()
    private var wasLidClosed = false

    /// Read again after every `lidChanges` yield, which is how an opened lid counts as an arrival.
    func current(at now: Date) -> Presence {
        let isLidClosed = Self.isLidClosed()
        if wasLidClosed, !isLidClosed { lastArrival = now }
        wasLidClosed = isLidClosed
        return Presence(
            isLidClosed: isLidClosed,
            hasExternalDisplay: Self.hasExternalDisplay(),
            idleTime: min(Self.inputIdleTime(), now.timeIntervalSince(lastArrival))
        )
    }

    /// Call when the Mac wakes, before reading the presence.
    func noteWake() {
        lastArrival = Date()
    }

    // MARK: System

    /// A Mac without a lid reads as open.
    private static func isLidClosed() -> Bool {
        let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        defer { IOObjectRelease(rootDomain) }
        let encoding = CFStringBuiltInEncodings.UTF8.rawValue
        guard
            let key = CFStringCreateWithCString(kCFAllocatorDefault, "AppleClamshellState", encoding),
            let state = IORegistryEntryCreateCFProperty(rootDomain, key, kCFAllocatorDefault, 0)?.takeRetainedValue()
        else { return false }
        return CFEqual(state, kCFBooleanTrue)
    }

    /// Online rather than active, so an external display that is asleep still counts.
    private static func hasExternalDisplay() -> Bool {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success else { return false }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else { return false }
        return displays.prefix(Int(count)).contains { CGDisplayIsBuiltin($0) == 0 }
    }

    /// Needs no permission, unlike reading the input itself.
    private static func inputIdleTime() -> TimeInterval {
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    /// Yields when the lid opens or closes, before any sleep the closing causes.
    nonisolated static func lidChanges() -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
            defer { IOObjectRelease(rootDomain) }
            guard rootDomain != IO_OBJECT_NULL, let port = IONotificationPortCreate(kIOMainPortDefault) else {
                continuation.finish()
                return
            }
            IONotificationPortSetDispatchQueue(port, .global())
            let box = Unmanaged.passRetained(ContinuationBox(continuation))
            var notifier = io_object_t()
            let result = IOServiceAddInterestNotification(
                port,
                rootDomain,
                kIOGeneralInterest,
                { refcon, _, messageType, _ in
                    guard messageType == clamshellStateChange, let refcon else { return }
                    Unmanaged<ContinuationBox>.fromOpaque(refcon).takeUnretainedValue().continuation.yield()
                },
                box.toOpaque(),
                &notifier
            )
            // The port is only touched again to destroy it, after the stream ends.
            nonisolated(unsafe) let ownedPort = port
            guard result == KERN_SUCCESS else {
                IONotificationPortDestroy(ownedPort)
                box.release()
                continuation.finish()
                return
            }
            continuation.onTermination = { [notifier] _ in
                IOObjectRelease(notifier)
                IONotificationPortDestroy(ownedPort)
                box.release()
            }
        }
    }

    private final class ContinuationBox: Sendable {
        let continuation: AsyncStream<Void>.Continuation

        init(_ continuation: AsyncStream<Void>.Continuation) {
            self.continuation = continuation
        }
    }
}
