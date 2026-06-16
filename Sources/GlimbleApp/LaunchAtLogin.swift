import ServiceManagement

/// Wraps SMAppService.mainApp for "open at login".
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Glimble: launch-at-login \(enabled ? "register" : "unregister") failed: \(error)")
        }
    }
}
