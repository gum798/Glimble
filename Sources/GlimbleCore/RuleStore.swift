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

    public func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(ruleSet).write(to: url, options: .atomic)
    }

    public static func load(from url: URL) throws -> RuleStore {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return RuleStore(ruleSet: RuleSet(version: 1, rules: []))
        }
        let data = try Data(contentsOf: url)
        let ruleSet = try JSONDecoder().decode(RuleSet.self, from: data)
        return RuleStore(ruleSet: ruleSet)
    }
}
