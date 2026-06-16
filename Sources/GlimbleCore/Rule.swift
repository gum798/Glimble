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
    /// Keyboard modifiers that must be held for this rule to fire, matched exactly.
    /// Empty means "no modifiers held".
    public var modifiers: [KeyModifier]
    public var enabled: Bool
    public init(id: UUID = UUID(), scope: RuleScope, trigger: RecognizedGesture,
                action: GlimbleAction, modifiers: [KeyModifier] = [], enabled: Bool = true) {
        self.id = id; self.scope = scope; self.trigger = trigger
        self.action = action; self.modifiers = modifiers; self.enabled = enabled
    }

    enum CodingKeys: String, CodingKey {
        case id, scope, trigger, action, enabled, modifiers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        scope = try container.decode(RuleScope.self, forKey: .scope)
        trigger = try container.decode(RecognizedGesture.self, forKey: .trigger)
        action = try container.decode(GlimbleAction.self, forKey: .action)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        // Backward-compat: old rules.json has no "modifiers" key.
        modifiers = try container.decodeIfPresent([KeyModifier].self, forKey: .modifiers) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(scope, forKey: .scope)
        try container.encode(trigger, forKey: .trigger)
        try container.encode(action, forKey: .action)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(modifiers, forKey: .modifiers)
    }
}

public extension Array where Element == KeyModifier {
    /// Canonical-order symbols, e.g. "⌃⌥⇧⌘" (empty for none).
    var symbols: String {
        var s = ""
        if contains(.control) { s += "⌃" }; if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }; if contains(.command) { s += "⌘" }
        return s
    }
}

public struct RuleSet: Codable, Equatable, Sendable {
    public var version: Int
    public var rules: [Rule]
    public init(version: Int = 1, rules: [Rule]) {
        self.version = version; self.rules = rules
    }
}
