import AppKit
import SwiftUI

/// Shows a SwiftUI view in a standard, reusable NSWindow (one per key). Brings the app
/// forward so the window is visible even though Glimble is an accessory (menu-bar) app.
@MainActor
final class WindowPresenter {
    private var windows: [String: NSWindow] = [:]

    func show<Content: View>(_ key: String, title: String, @ViewBuilder content: () -> Content) {
        if let existing = windows[key] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false)
        window.title = title
        window.contentViewController = NSHostingController(rootView: content())
        window.isReleasedWhenClosed = false
        window.center()
        windows[key] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
