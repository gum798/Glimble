import AppKit
import CoreGraphics
import GlimbleCore

/// Executes a `GlimbleAction`. All event synthesis and process spawning lives here.
@MainActor
enum ActionExecutor {
    static func run(_ action: GlimbleAction) {
        switch action {
        case .keyboardShortcut(let combo):
            postKeyboardShortcut(combo)
        case .shell, .appleScript, .runShortcut, .launchApp, .window:
            break   // implemented in later tasks
        }
    }

    private static func postKeyboardShortcut(_ combo: KeyCombo) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: false)
        else { return }
        down.flags = combo.cgEventFlags
        up.flags = combo.cgEventFlags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
