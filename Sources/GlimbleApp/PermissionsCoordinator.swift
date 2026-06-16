import AppKit
import ApplicationServices
import CoreGraphics

/// Per-capability TCC status + request + deep links. Input Monitoring is needed to READ
/// touches; Accessibility is needed to synthesize keys and move windows.
@MainActor
final class PermissionsCoordinator: ObservableObject {
    @Published var inputMonitoringGranted = false
    @Published var accessibilityGranted = false

    func refresh() {
        inputMonitoringGranted = CGPreflightListenEventAccess()
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestInputMonitoring() {
        if !CGPreflightListenEventAccess() { CGRequestListenEventAccess() }
        openSettings(pane: "Privacy_ListenEvent")
    }

    func requestAccessibility() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        openSettings(pane: "Privacy_Accessibility")
    }

    private func openSettings(pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
