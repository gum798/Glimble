import Testing
import Foundation
@testable import GlimbleCore

private func r(_ id: Int, _ trigger: RecognizedGesture, enabled: Bool = true) -> Rule {
    Rule(id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", id))")!,
         scope: .global, trigger: trigger, action: .window(.maximize), enabled: enabled)
}

@Test func addingAppendsRule() {
    let set = RuleSet(rules: [r(1, .tap(fingers: 3))])
    let out = set.adding(r(2, .tap(fingers: 4)))
    #expect(out.rules.count == 2)
    #expect(out.rules.last?.trigger == .tap(fingers: 4))
}

@Test func removingDropsByID() {
    let set = RuleSet(rules: [r(1, .tap(fingers: 3)), r(2, .tap(fingers: 4))])
    let out = set.removing(id: r(1, .tap(fingers: 3)).id)
    #expect(out.rules.count == 1)
    #expect(out.rules.first?.trigger == .tap(fingers: 4))
}

@Test func updatingReplacesMatchingID() {
    let original = r(1, .tap(fingers: 3))
    var edited = original
    edited.enabled = false
    let out = RuleSet(rules: [original]).updating(edited)
    #expect(out.rules.first?.enabled == false)
}

@Test func togglingFlipsEnabled() {
    let set = RuleSet(rules: [r(1, .tap(fingers: 3), enabled: true)])
    let out = set.togglingEnabled(id: set.rules[0].id)
    #expect(out.rules.first?.enabled == false)
}
