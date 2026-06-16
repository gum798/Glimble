import SwiftUI
import AppKit
import GlimbleCore

/// Captures a real keyboard shortcut (key + modifiers) by grabbing the next key-down event.
@MainActor
final class ShortcutCapturer: ObservableObject {
    @Published var capturing = false
    private var monitor: Any?

    /// Called with the captured key code + modifiers (not called if the user presses Escape).
    var onCapture: ((UInt16, [KeyModifier]) -> Void)?

    func start() {
        guard monitor == nil else { return }
        capturing = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            MainActor.assumeIsolated {
                if event.keyCode == 53 {          // Escape cancels
                    self.stop()
                } else {
                    self.onCapture?(event.keyCode, ShortcutFormatting.modifiers(from: event.modifierFlags))
                    self.stop()
                }
            }
            return nil   // swallow the captured keypress
        }
    }

    func stop() {
        capturing = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

/// A field that shows the current shortcut and records a new one on click.
struct ShortcutField: View {
    @Binding var keyCode: UInt16?
    @Binding var modifiers: [KeyModifier]
    @StateObject private var capturer = ShortcutCapturer()

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(keyCode == nil ? .secondary : .primary)
                .font(.body.monospaced())
            Spacer()
            Button(capturer.capturing ? "Press keys… (Esc cancels)" : "Record Shortcut") {
                if capturer.capturing {
                    capturer.stop()
                } else {
                    capturer.onCapture = { code, mods in
                        keyCode = code
                        modifiers = mods
                    }
                    capturer.start()
                }
            }
        }
        .onDisappear { capturer.stop() }
    }

    private var label: String {
        guard let keyCode else { return "No shortcut" }
        return ShortcutFormatting.string(keyCode: keyCode, modifiers: modifiers)
    }
}

/// Formatting + modifier mapping for shortcuts (display only; the model stores key code + mods).
enum ShortcutFormatting {
    static func modifiers(from flags: NSEvent.ModifierFlags) -> [KeyModifier] {
        var mods: [KeyModifier] = []
        if flags.contains(.control) { mods.append(.control) }
        if flags.contains(.option) { mods.append(.option) }
        if flags.contains(.shift) { mods.append(.shift) }
        if flags.contains(.command) { mods.append(.command) }
        return mods
    }

    /// e.g. "⌘⇧→". Modifiers are shown in the conventional ⌃⌥⇧⌘ order.
    static func string(keyCode: UInt16, modifiers: [KeyModifier]) -> String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option)  { s += "⌥" }
        if modifiers.contains(.shift)   { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + keyLabel(keyCode)
    }

    /// US-layout label for a virtual key code (display only — the stored key code is authoritative).
    static func keyLabel(_ code: UInt16) -> String {
        switch code {
        case 36: return "Return";  case 76: return "Enter"
        case 48: return "Tab";     case 49: return "Space"
        case 51: return "Delete";  case 117: return "Fwd Del"
        case 53: return "Esc"
        case 123: return "←"; case 124: return "→"; case 125: return "↓"; case 126: return "↑"
        case 115: return "Home"; case 119: return "End"
        case 116: return "Page Up"; case 121: return "Page Down"
        case 0: return "A"; case 1: return "S"; case 2: return "D"; case 3: return "F"
        case 4: return "H"; case 5: return "G"; case 6: return "Z"; case 7: return "X"
        case 8: return "C"; case 9: return "V"; case 11: return "B"; case 12: return "Q"
        case 13: return "W"; case 14: return "E"; case 15: return "R"; case 16: return "Y"
        case 17: return "T"; case 31: return "O"; case 32: return "U"; case 34: return "I"
        case 35: return "P"; case 37: return "L"; case 38: return "J"; case 40: return "K"
        case 45: return "N"; case 46: return "M"
        case 18: return "1"; case 19: return "2"; case 20: return "3"; case 21: return "4"
        case 23: return "5"; case 22: return "6"; case 26: return "7"; case 28: return "8"
        case 25: return "9"; case 29: return "0"
        case 122: return "F1"; case 120: return "F2"; case 99: return "F3";  case 118: return "F4"
        case 96: return "F5";  case 97: return "F6";  case 98: return "F7";  case 100: return "F8"
        case 101: return "F9"; case 109: return "F10"; case 103: return "F11"; case 111: return "F12"
        default: return "key \(code)"
        }
    }
}
