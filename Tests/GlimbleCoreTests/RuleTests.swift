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
