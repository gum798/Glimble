import Foundation
import OpenMultitouchSupport

/// Isolates ALL private-framework access (via OpenMultitouchSupport) behind one type,
/// emitting only an active-finger count. This is the seed of the Phase 1 `TouchSource` module.
///
/// Main-actor isolated: the spike's only consumer is the menu-bar UI, and the inherited
/// `Task` then delivers counts on the main actor with no hop. Phase 1's real `TouchSource`
/// will move the hot recognition path off the main actor.
@MainActor
final class TouchReader {
    private let manager = OMSManager.shared
    private var task: Task<Void, Never>?

    /// Called on the main actor with the current number of fingers actively touching.
    var onCount: ((Int) -> Void)?

    func start() {
        manager.startListening()
        task = Task { [weak self] in
            guard let self else { return }
            for await touches in self.manager.touchDataStream {
                let active = touches.filter { $0.state == .touching }.count
                self.onCount?(active)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        manager.stopListening()
    }
}
