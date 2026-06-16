import Foundation
import GlimbleCore

/// Runs the frame→gesture→action pipeline against the shared RulesModel.
///
/// `recordingSink`, if set, is offered each recognized gesture first; if it returns `true`
/// (the recorder consumed it, i.e. the settings editor is actively recording) the gesture is
/// NOT executed. When not recording it returns `false`, so normal action execution proceeds.
@MainActor
final class GestureEngine {
    private var recognizer = GestureRecognizer()
    private let rules: RulesModel

    /// Returns `true` if the gesture was consumed for recording (so no action should run).
    var recordingSink: ((RecognizedGesture) -> Bool)?

    init(rules: RulesModel) {
        self.rules = rules
    }

    func handle(_ frame: TouchFrame) {
        guard let gesture = recognizer.process(frame) else { return }
        if recordingSink?(gesture) == true { return }   // captured by the recorder; don't execute
        guard let action = rules.action(for: gesture, frontmostBundleID: AppContext.frontmostBundleID)
        else { return }
        ActionExecutor.run(action)
    }
}
