import Foundation

/// What the UI can ask for. Presets rather than timestamps: the controller owns the clock and calendar.
enum BeeCommand: Equatable {
    case keepAwake(KeepAwakeDuration)
    case pause(PauseLength)
    case resumeAutomatic
    case setSchedule(Schedule)
    case setBatteryLimit(BatteryLimit)
    case setIntegration(IntegrationID, enabled: Bool)
    case setOption(BeeOption, Bool)
}

/// An on/off choice in Settings.
enum BeeOption: Equatable {
    case launchAtLogin
    case preventsDisplaySleep
    case keepsAwakeWithLidClosed
    case keepsAwakeForT3AutoResume
}

/// Mirrors `SMAppService.mainApp.status`, which is the source of truth, so it is never persisted.
enum LoginItemStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case failed(String)
}
