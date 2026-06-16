import AppKit
import Foundation
import GlimbleCore

/// Runs the frame→gesture→action pipeline against the shared RulesModel.
///
/// Taps pass through a `TapCombiner` that merges two quick same-finger taps into a `.doubleTap`.
/// A first tap is only held (delayed) when recording or when a double-tap rule exists for that
/// finger count, so single taps stay latency-free otherwise.
///
/// `recordingSink`, if set, is offered each delivered gesture first; if it returns `true` (the
/// recorder consumed it, i.e. the settings editor is actively recording) the gesture is NOT
/// executed. `isRecordingActive` lets the combiner know to hold taps while recording.
@MainActor
final class GestureEngine {
    private var recognizer = GestureRecognizer()
    private var combiner = TapCombiner()
    private var flushTask: Task<Void, Never>?
    private let rules: RulesModel
    private let settings: AppSettings

    /// Returns `true` if the gesture was consumed for recording (so no action should run).
    var recordingSink: ((RecognizedGesture, [KeyModifier]) -> Bool)?
    /// Whether the editor is currently waiting to record a gesture.
    var isRecordingActive: (() -> Bool)?

    init(rules: RulesModel, settings: AppSettings) {
        self.rules = rules
        self.settings = settings
    }

    /// The keyboard modifiers currently physically held, in canonical order.
    static func currentModifiers() -> [KeyModifier] {
        let f = NSEvent.modifierFlags
        var m: [KeyModifier] = []
        if f.contains(.control) { m.append(.control) }
        if f.contains(.option) { m.append(.option) }
        if f.contains(.shift) { m.append(.shift) }
        if f.contains(.command) { m.append(.command) }
        return m
    }

    func handle(_ frame: TouchFrame) {
        combiner.doubleTapWindow = settings.doubleTapWindow
        guard let raw = recognizer.process(frame) else { return }
        let delivered = combiner.input(raw, now: Self.now()) { [weak self] fingers, count in
            self?.wantsMoreTaps(fingers: fingers, after: count) ?? false
        }
        for gesture in delivered { deliver(gesture) }
        rescheduleFlush()
    }

    private func deliver(_ gesture: RecognizedGesture) {
        let mods = Self.currentModifiers()
        if recordingSink?(gesture, mods) == true { return }   // captured by the recorder; don't execute
        guard let action = rules.action(for: gesture, frontmostBundleID: AppContext.frontmostBundleID,
                                        heldModifiers: mods)
        else { return }
        ActionExecutor.run(action)
    }

    /// Whether to keep holding for one more tap after reaching `count` taps: yes while recording,
    /// or when a rule needs more taps for this finger count (double rule → reach 2; triple → reach 3).
    private func wantsMoreTaps(fingers: Int, after count: Int) -> Bool {
        if isRecordingActive?() == true { return true }
        let rs = rules.ruleSet.rules
        func has(_ g: RecognizedGesture) -> Bool { rs.contains { $0.enabled && $0.trigger == g } }
        switch count {
        case 1: return has(.doubleTap(fingers: fingers)) || has(.tripleTap(fingers: fingers))
        case 2: return has(.tripleTap(fingers: fingers))
        default: return false
        }
    }

    /// (Re)arm a timer to flush a held tap once its double-tap window expires.
    private func rescheduleFlush() {
        flushTask?.cancel()
        flushTask = nil
        guard let deadline = combiner.pendingDeadline else { return }
        let delay = max(0, deadline - Self.now())
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            for gesture in self.combiner.flush(now: Self.now()) { self.deliver(gesture) }
        }
    }

    private static func now() -> TimeInterval { ProcessInfo.processInfo.systemUptime }
}
