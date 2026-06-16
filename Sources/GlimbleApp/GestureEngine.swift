import Foundation
import GlimbleCore

/// Runs the frame→gesture→action pipeline against the shared RulesModel.
/// While `onRecognized` is set, gestures are delivered there and NOT executed (recording mode).
@MainActor
final class GestureEngine {
    private var recognizer = GestureRecognizer()
    private let rules: RulesModel

    /// When non-nil, the next recognized gestures go here instead of running an action.
    var onRecognized: ((RecognizedGesture) -> Void)?

    init(rules: RulesModel) {
        self.rules = rules
    }

    func handle(_ frame: TouchFrame) {
        guard let gesture = recognizer.process(frame) else { return }
        if let recorder = onRecognized {
            recorder(gesture)
            return
        }
        guard let action = rules.action(for: gesture, frontmostBundleID: AppContext.frontmostBundleID)
        else { return }
        ActionExecutor.run(action)
    }
}
