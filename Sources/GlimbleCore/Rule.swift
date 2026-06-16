import Foundation

public enum KeyModifier: String, Codable, Equatable, Sendable, CaseIterable {
    case command, option, control, shift
}

public struct KeyCombo: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    public var modifiers: [KeyModifier]
    public init(keyCode: UInt16, modifiers: [KeyModifier]) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public enum GlimbleAction: Codable, Equatable, Sendable {
    case keyboardShortcut(KeyCombo)
    case shell(String)
    case appleScript(String)
    case runShortcut(String)
    case launchApp(bundleID: String)
    case window(SnapPosition)
}

public enum RuleScope: Codable, Equatable, Sendable {
    case global
    case app(bundleID: String)
}

public struct Rule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var scope: RuleScope
    public var trigger: RecognizedGesture
    public var action: GlimbleAction
    public var enabled: Bool
    public init(id: UUID = UUID(), scope: RuleScope, trigger: RecognizedGesture,
                action: GlimbleAction, enabled: Bool = true) {
        self.id = id; self.scope = scope; self.trigger = trigger
        self.action = action; self.enabled = enabled
    }
}

public struct RuleSet: Codable, Equatable, Sendable {
    public var version: Int
    public var rules: [Rule]
    public init(version: Int = 1, rules: [Rule]) {
        self.version = version; self.rules = rules
    }
}
