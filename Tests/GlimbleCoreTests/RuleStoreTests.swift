import Testing
import Foundation
@testable import GlimbleCore

private func rule(_ scope: RuleScope, _ trigger: RecognizedGesture, _ action: GlimbleAction,
                  enabled: Bool = true) -> Rule {
    Rule(scope: scope, trigger: trigger, action: action, enabled: enabled)
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

@Test func disabledRulesAreIgnored() {
    let store = RuleStore(ruleSet: RuleSet(rules: [
        rule(.global, .tap(fingers: 2), .window(.center), enabled: false),
    ]))
    #expect(store.action(for: .tap(fingers: 2), frontmostBundleID: nil) == nil)
}
