import Foundation
import CoreGraphics
import GlimbleCore
import OpenMultitouchSupport

/// Wraps OpenMultitouchSupport, normalizing each emission into a GlimbleCore `TouchFrame`.
/// ALL private-framework access is isolated here. Main-actor isolated (UI is the only consumer).
@MainActor
final class TouchSource {
    private let manager = OMSManager.shared
    private var task: Task<Void, Never>?
    private var frameCounter: TimeInterval = 0

    /// Called on the main actor with each normalized frame.
    var onFrame: ((TouchFrame) -> Void)?

    func start() {
        manager.startListening()
        task = Task { [weak self] in
            guard let self else { return }
            // The OMS stream coalesces to the newest frame under back-pressure, so intermediate
            // frames can be dropped. The recognizer tolerates this by tracking max/peak rather
            // than integrating per-frame — keep `onFrame`/`engine.handle` cheap so frames flow.
            for await touches in self.manager.touchDataStream {
                let frame = Self.normalize(touches, sequence: self.nextTimestamp())
                self.onFrame?(frame)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        manager.stopListening()
    }

    private func nextTimestamp() -> TimeInterval {
        frameCounter += 0.01
        return frameCounter
    }

    private static func normalize(_ touches: [OMSTouchData], sequence t: TimeInterval) -> TouchFrame {
        let fingers = touches
            .filter { $0.state == .touching }
            .map { d in
                Finger(id: d.id,
                       position: CGPoint(x: CGFloat(d.position.x), y: CGFloat(d.position.y)),
                       pressure: d.pressure)
            }
        return TouchFrame(fingers: fingers, timestamp: t)
    }
}
