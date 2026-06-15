import AppKit
import ApplicationServices
import GlimbleCore

enum WindowSnapError: Error {
    case noFrontmostApp
    case noFocusedWindow
    case axError(AXError)
}

/// Snaps the frontmost app's focused window using only the public Accessibility API.
/// Seed of the Phase 1 window-management half of `ActionExecutor`.
/// Main-actor isolated because it reads `NSWorkspace`/`NSScreen` (both `@MainActor`).
@MainActor
enum WindowSnapper {

    static func snapFocusedWindow(to position: SnapPosition) throws {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            throw WindowSnapError.noFrontmostApp
        }
        let axApp = AXUIElementCreateApplication(frontApp.processIdentifier)

        var windowRef: CFTypeRef?
        let windowErr = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef)
        guard windowErr == .success, let windowRef else {
            throw WindowSnapError.noFocusedWindow
        }
        let axWindow = windowRef as! AXUIElement

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let vf = screen.visibleFrame
        let primaryHeight = (NSScreen.screens.first { $0.frame.origin == .zero } ?? screen).frame.height

        let appKitRect = WindowGeometry.snapRect(position, in: vf)
        var axPoint = WindowGeometry.axOrigin(forAppKitRect: appKitRect, primaryHeight: primaryHeight)
        var size = appKitRect.size

        // EnhancedUserInterface workaround (Chrome / Electron / Office): read from the
        // APPLICATION element, disable before resize, restore after.
        let hadEnhancedUI = readEnhancedUserInterface(axApp)
        if hadEnhancedUI { setEnhancedUserInterface(axApp, false) }
        defer { if hadEnhancedUI { setEnhancedUserInterface(axApp, true) } }

        // size → position → size so cross-display moves survive macOS size clamping.
        try setSize(axWindow, &size)
        try setPosition(axWindow, &axPoint)
        try setSize(axWindow, &size)
    }

    private static func setPosition(_ window: AXUIElement, _ point: inout CGPoint) throws {
        guard let value = AXValueCreate(.cgPoint, &point) else { throw WindowSnapError.noFocusedWindow }
        let err = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        if err != .success { throw WindowSnapError.axError(err) }
    }

    private static func setSize(_ window: AXUIElement, _ size: inout CGSize) throws {
        guard let value = AXValueCreate(.cgSize, &size) else { throw WindowSnapError.noFocusedWindow }
        let err = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        if err != .success { throw WindowSnapError.axError(err) }
    }

    private static func readEnhancedUserInterface(_ axApp: AXUIElement) -> Bool {
        var current: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, &current)
        return (current as? Bool) ?? false
    }

    private static func setEnhancedUserInterface(_ axApp: AXUIElement, _ enabled: Bool) {
        let value: CFTypeRef = enabled ? kCFBooleanTrue : kCFBooleanFalse
        AXUIElementSetAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, value)
    }
}
