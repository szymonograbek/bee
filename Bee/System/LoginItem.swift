import ServiceManagement

/// Bee as a login item. `SMAppService.mainApp` is the source of truth, so the status is never persisted.
enum LoginItem {
    static func set(_ launches: Bool) -> LoginItemStatus {
        do {
            if launches {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return status
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    static var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered, .notFound: .disabled
        @unknown default: .disabled
        }
    }
}
