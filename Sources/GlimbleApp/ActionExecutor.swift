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
        case .shell(let command):
            runProcess("/bin/zsh", ["-c", command])
        case .appleScript(let script):
            runProcess("/usr/bin/osascript", ["-e", script])
        case .runShortcut(let name):
            runProcess("/usr/bin/shortcuts", ["run", name])
        case .launchApp(let bundleID):
            launchApp(bundleID: bundleID)
        case .window(let position):
            try? WindowSnapper.snapFocusedWindow(to: position)
        }
    }

    private static func runProcess(_ launchPath: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        do { try process.run() } catch { NSLog("Glimble: failed to run \(launchPath): \(error)") }
    }

    private static func launchApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
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
