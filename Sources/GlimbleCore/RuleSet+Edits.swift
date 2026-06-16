import Foundation

public extension RuleSet {
    func adding(_ rule: Rule) -> RuleSet {
        RuleSet(version: version, rules: rules + [rule])
    }
    func updating(_ rule: Rule) -> RuleSet {
        RuleSet(version: version, rules: rules.map { $0.id == rule.id ? rule : $0 })
    }
    func removing(id: UUID) -> RuleSet {
        RuleSet(version: version, rules: rules.filter { $0.id != id })
    }
    func togglingEnabled(id: UUID) -> RuleSet {
        RuleSet(version: version, rules: rules.map {
            var r = $0
            if r.id == id { r.enabled.toggle() }
            return r
        })
    }
}
