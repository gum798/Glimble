import Foundation
import AppKit
import GlimbleCore

/// Owns the recognizer + rule store and runs the frame→gesture→action pipeline.
@MainActor
final class GestureEngine {
    private var recognizer = GestureRecognizer()
    private(set) var store: RuleStore

    /// The on-disk rule file: ~/Library/Application Support/Glimble/rules.json
    static var rulesURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Glimble", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("rules.json")
    }

    init() {
        let loaded = (try? RuleStore.load(from: Self.rulesURL)) ?? RuleStore(ruleSet: .init(rules: []))
        if loaded.ruleSet.rules.isEmpty {
            store = RuleStore(ruleSet: DefaultPresets.ruleSet)
            try? store.write(to: Self.rulesURL)
        } else {
            store = loaded
        }
    }

    /// Feed one frame; if it completes a gesture with a matching rule, run the action.
    func handle(_ frame: TouchFrame) {
        guard let gesture = recognizer.process(frame) else { return }
        guard let action = store.action(for: gesture, frontmostBundleID: AppContext.frontmostBundleID)
        else { return }
        ActionExecutor.run(action)
    }
}
