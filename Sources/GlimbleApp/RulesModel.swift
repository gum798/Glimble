import Foundation
import GlimbleCore

/// Observable single source of truth for rules. Persists to disk on every mutation.
/// Shared by the GestureEngine (reads) and the settings UI (edits).
@MainActor
final class RulesModel: ObservableObject {
    @Published private(set) var ruleSet: RuleSet

    private let url: URL

    /// The on-disk rule file: ~/Library/Application Support/Glimble/rules.json
    static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Glimble", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("rules.json")
    }

    init(url: URL = RulesModel.defaultURL) {
        self.url = url
        let loaded = (try? RuleStore.load(from: url))?.ruleSet ?? RuleSet(rules: [])
        if loaded.rules.isEmpty {
            ruleSet = DefaultPresets.ruleSet
            persist()
        } else {
            ruleSet = loaded
        }
    }

    /// Current resolution used by the engine.
    func action(for gesture: RecognizedGesture, frontmostBundleID: String?) -> GlimbleAction? {
        RuleStore(ruleSet: ruleSet).action(for: gesture, frontmostBundleID: frontmostBundleID)
    }

    func add(_ rule: Rule)          { mutate { $0.adding(rule) } }
    func update(_ rule: Rule)       { mutate { $0.updating(rule) } }
    func remove(id: UUID)           { mutate { $0.removing(id: id) } }
    func toggle(id: UUID)           { mutate { $0.togglingEnabled(id: id) } }

    private func mutate(_ transform: (RuleSet) -> RuleSet) {
        ruleSet = transform(ruleSet)
        persist()
    }

    private func persist() {
        try? RuleStore(ruleSet: ruleSet).write(to: url)
    }
}
