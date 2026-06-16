import Testing
import Foundation
@testable import GlimbleCore

private func rule(_ scope: RuleScope, _ trigger: RecognizedGesture, _ action: GlimbleAction,
                  modifiers: [KeyModifier] = [], enabled: Bool = true) -> Rule {
    Rule(scope: scope, trigger: trigger, action: action, modifiers: modifiers, enabled: enabled)
}

@Test func matchesGlobalRule() {
    let store = RuleStore(ruleSet: RuleSet(rules: [
        rule(.global, .tap(fingers: 3), .window(.maximize)),
    ]))
    #expect(store.action(for: .tap(fingers: 3), frontmostBundleID: nil) == .window(.maximize))
    #expect(store.action(for: .tap(fingers: 4), frontmostBundleID: nil) == nil)
}

@Test func appScopedRuleWinsOverGlobal() {
    let store = RuleStore(ruleSet: RuleSet(rules: [
        rule(.global, .swipe(fingers: 3, direction: .left), .window(.left)),
        rule(.app(bundleID: "com.google.Chrome"), .swipe(fingers: 3, direction: .left),
             .keyboardShortcut(KeyCombo(keyCode: 123, modifiers: [.command]))),
    ]))
    #expect(store.action(for: .swipe(fingers: 3, direction: .left), frontmostBundleID: "com.google.Chrome")
            == .keyboardShortcut(KeyCombo(keyCode: 123, modifiers: [.command])))
    #expect(store.action(for: .swipe(fingers: 3, direction: .left), frontmostBundleID: "com.apple.Finder")
            == .window(.left))
}

@Test func ruleWithModifiersMatchesOnlyWhenHeldExactly() {
    let store = RuleStore(ruleSet: RuleSet(rules: [
        rule(.global, .tap(fingers: 3), .window(.maximize), modifiers: [.command]),
    ]))
    #expect(store.action(for: .tap(fingers: 3), frontmostBundleID: nil,
                         heldModifiers: [.command]) == .window(.maximize))
    #expect(store.action(for: .tap(fingers: 3), frontmostBundleID: nil,
                         heldModifiers: []) == nil)
    #expect(store.action(for: .tap(fingers: 3), frontmostBundleID: nil,
                         heldModifiers: [.command, .shift]) == nil)
    #expect(store.action(for: .tap(fingers: 3), frontmostBundleID: nil,
                         heldModifiers: [.option]) == nil)
}

@Test func ruleWithoutModifiersMatchesOnlyWhenNoneHeld() {
    let store = RuleStore(ruleSet: RuleSet(rules: [
        rule(.global, .tap(fingers: 3), .window(.center)),
    ]))
    #expect(store.action(for: .tap(fingers: 3), frontmostBundleID: nil,
                         heldModifiers: []) == .window(.center))
    #expect(store.action(for: .tap(fingers: 3), frontmostBundleID: nil,
                         heldModifiers: [.command]) == nil)
    // Default heldModifiers argument means "none held".
    #expect(store.action(for: .tap(fingers: 3), frontmostBundleID: nil) == .window(.center))
}

@Test func disabledRulesAreIgnored() {
    let store = RuleStore(ruleSet: RuleSet(rules: [
        rule(.global, .tap(fingers: 2), .window(.center), enabled: false),
    ]))
    #expect(store.action(for: .tap(fingers: 2), frontmostBundleID: nil) == nil)
}

@Test func ruleStoreWritesAndLoadsFromDisk() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("glimble-test-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let original = RuleStore(ruleSet: RuleSet(rules: [
        rule(.global, .tap(fingers: 3), .shell("echo hi")),
    ]))
    try original.write(to: url)
    let loaded = try RuleStore.load(from: url)
    #expect(loaded.ruleSet == original.ruleSet)
}

@Test func loadingMissingFileReturnsEmptyRuleSet() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("glimble-missing-\(UUID().uuidString).json")
    let store = try RuleStore.load(from: url)
    #expect(store.ruleSet.rules.isEmpty)
    #expect(store.ruleSet.version == 1)
}
