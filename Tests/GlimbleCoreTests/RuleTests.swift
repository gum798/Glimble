import Testing
import Foundation
@testable import GlimbleCore

@Test func ruleSetRoundTripsThroughJSON() throws {
    let rules = RuleSet(version: 1, rules: [
        Rule(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
             scope: .global,
             trigger: .swipe(fingers: 3, direction: .left),
             action: .keyboardShortcut(KeyCombo(keyCode: 123, modifiers: [.command])),
             enabled: true),
        Rule(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
             scope: .app(bundleID: "com.google.Chrome"),
             trigger: .tap(fingers: 4),
             action: .window(.maximize),
             enabled: false),
    ])
    let data = try JSONEncoder().encode(rules)
    let decoded = try JSONDecoder().decode(RuleSet.self, from: data)
    #expect(decoded == rules)
}

@Test func ruleRoundTripsWithModifiers() throws {
    let rule = Rule(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                    scope: .global,
                    trigger: .tap(fingers: 3),
                    action: .window(.maximize),
                    modifiers: [.command])
    let data = try JSONEncoder().encode(rule)
    let decoded = try JSONDecoder().decode(Rule.self, from: data)
    #expect(decoded == rule)
    #expect(decoded.modifiers == [.command])
}

@Test func decodingRuleSetWithoutModifiersDefaultsToEmpty() throws {
    let json = """
    {
      "version": 1,
      "rules": [
        {
          "id": "00000000-0000-0000-0000-000000000004",
          "scope": { "global": {} },
          "trigger": { "tap": { "fingers": 3 } },
          "action": { "window": { "_0": "maximize" } },
          "enabled": true
        }
      ]
    }
    """
    let decoded = try JSONDecoder().decode(RuleSet.self, from: Data(json.utf8))
    #expect(decoded.rules.count == 1)
    #expect(decoded.rules[0].modifiers == [])
}

@Test func modifierSymbolsAreCanonicallyOrdered() {
    #expect([KeyModifier]().symbols == "")
    #expect([KeyModifier.command].symbols == "⌘")
    #expect([KeyModifier.command, .shift, .control, .option].symbols == "⌃⌥⇧⌘")
}

@Test func everyActionKindEncodes() throws {
    let actions: [GlimbleAction] = [
        .keyboardShortcut(KeyCombo(keyCode: 48, modifiers: [.command, .shift])),
        .shell("echo hi"),
        .appleScript("display dialog \"x\""),
        .runShortcut("My Shortcut"),
        .launchApp(bundleID: "com.apple.Safari"),
        .window(.left),
    ]
    let data = try JSONEncoder().encode(actions)
    #expect(try JSONDecoder().decode([GlimbleAction].self, from: data) == actions)
}
