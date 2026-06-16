import Foundation

/// Curated starter rules so Glimble is useful immediately. All global + enabled.
/// Deterministic UUIDs keep the set stable across launches.
public enum DefaultPresets {
    public static let ruleSet = RuleSet(version: 1, rules: [
        Rule(id: uuid(1), scope: .global, trigger: .tap(fingers: 3), action: .window(.maximize)),
        Rule(id: uuid(2), scope: .global, trigger: .tap(fingers: 4), action: .window(.center)),
        Rule(id: uuid(3), scope: .global, trigger: .swipe(fingers: 3, direction: .left), action: .window(.left)),
        Rule(id: uuid(4), scope: .global, trigger: .swipe(fingers: 3, direction: .right), action: .window(.right)),
    ])

    private static func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
    }
}
