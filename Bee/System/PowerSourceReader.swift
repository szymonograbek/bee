import Foundation
import IOKit.ps
import notify

/// Reads the power adapter and internal battery from IOKit.
enum PowerSourceReader {
    /// An unreadable snapshot reads as plugged in without a battery, so the battery limit never applies by mistake.
    static func current() -> PowerSource {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return PowerSource(isPluggedIn: true, batteryCharge: nil)
        }
        let providing = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue()
        return PowerSource(
            isPluggedIn: providing.map { matches($0, kIOPMACPowerKey) } ?? true,
            batteryCharge: internalBatteryCharge(info)
        )
    }

    /// Yields whenever the power source or the battery charge changes.
    static func changes() -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            var token: Int32 = 0
            let status = notify_register_dispatch(kIOPSNotifyAnyPowerSource, &token, .global()) { _ in
                continuation.yield()
            }
            guard status == NOTIFY_STATUS_OK else {
                continuation.finish()
                return
            }
            continuation.onTermination = { [token] _ in notify_cancel(token) }
        }
    }

    private static func internalBatteryCharge(_ info: CFTypeRef) -> Int? {
        guard let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() else { return nil }
        for index in 0..<CFArrayGetCount(list) {
            guard
                let source = CFArrayGetValueAtIndex(list, index),
                let description = IOPSGetPowerSourceDescription(info, object(source))?.takeUnretainedValue(),
                let type = value(description, kIOPSTypeKey), matches(type, kIOPSInternalBatteryType),
                let current = int(description, kIOPSCurrentCapacityKey),
                let max = int(description, kIOPSMaxCapacityKey), max > 0
            else { continue }
            return current * 100 / max
        }
        return nil
    }

    // MARK: CoreFoundation

    // IOKit hands back untyped CF values. These check each value's CF type instead of asserting a Swift type.

    private static func object(_ pointer: UnsafeRawPointer) -> CFTypeRef {
        Unmanaged<CFTypeRef>.fromOpaque(pointer).takeUnretainedValue()
    }

    private static func lookup(_ dictionary: CFDictionary, _ key: String) -> UnsafeRawPointer? {
        guard let key = cfString(key) else { return nil }
        return CFDictionaryGetValue(dictionary, Unmanaged.passUnretained(key).toOpaque())
    }

    private static func value(_ dictionary: CFDictionary, _ key: String) -> CFTypeRef? {
        lookup(dictionary, key).map(object)
    }

    private static func int(_ dictionary: CFDictionary, _ key: String) -> Int? {
        guard
            let pointer = lookup(dictionary, key),
            CFGetTypeID(object(pointer)) == CFNumberGetTypeID()
        else { return nil }
        var result = 0
        let number = Unmanaged<CFNumber>.fromOpaque(pointer).takeUnretainedValue()
        return CFNumberGetValue(number, .nsIntegerType, &result) ? result : nil
    }

    private static func matches(_ value: CFTypeRef, _ string: String) -> Bool {
        guard let string = cfString(string) else { return false }
        return CFEqual(value, string)
    }

    private static func cfString(_ string: String) -> CFString? {
        CFStringCreateWithCString(kCFAllocatorDefault, string, CFStringBuiltInEncodings.UTF8.rawValue)
    }
}
