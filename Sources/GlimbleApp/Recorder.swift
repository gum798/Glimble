import Foundation
import GlimbleCore

/// Drives the "perform a gesture to set the trigger" flow in the rule editor.
/// The AppDelegate connects the engine's recognized gestures to `capture(_:)` while recording.
@MainActor
final class Recorder: ObservableObject {
    @Published var isRecording = false
    @Published var captured: RecognizedGesture?

    func start() {
        captured = nil
        isRecording = true
    }

    func cancel() {
        isRecording = false
    }

    /// Called by the engine bridge with a recognized gesture while recording.
    func capture(_ gesture: RecognizedGesture) {
        guard isRecording else { return }
        captured = gesture
        isRecording = false
    }
}
