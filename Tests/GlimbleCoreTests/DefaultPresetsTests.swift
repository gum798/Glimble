import Testing
@testable import GlimbleCore

@Test func defaultPresetsCoverTheStarterGestures() {
    let store = RuleStore(ruleSet: DefaultPresets.ruleSet)
    #expect(store.action(for: .tap(fingers: 3), frontmostBundleID: nil) == .window(.maximize))
    #expect(store.action(for: .tap(fingers: 4), frontmostBundleID: nil) == .window(.center))
    #expect(store.action(for: .swipe(fingers: 3, direction: .left), frontmostBundleID: nil) == .window(.left))
    #expect(store.action(for: .swipe(fingers: 3, direction: .right), frontmostBundleID: nil) == .window(.right))
}

@Test func defaultPresetsAreAllGlobalAndEnabled() {
    for r in DefaultPresets.ruleSet.rules {
        #expect(r.enabled)
        #expect(r.scope == .global)
    }
}
