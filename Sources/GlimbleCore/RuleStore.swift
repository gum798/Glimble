import Foundation

public struct RuleStore: Sendable {
    public private(set) var ruleSet: RuleSet
    public init(ruleSet: RuleSet) { self.ruleSet = ruleSet }

    public func action(for gesture: RecognizedGesture, frontmostBundleID: String?) -> GlimbleAction? {
        let candidates = ruleSet.rules.filter { $0.enabled && $0.trigger == gesture }
        if let bundleID = frontmostBundleID,
           let appRule = candidates.first(where: { $0.scope == .app(bundleID: bundleID) }) {
            return appRule.action
        }
        return candidates.first(where: { $0.scope == .global })?.action
    }
}
