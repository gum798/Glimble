import Testing
import CoreGraphics
import Foundation
@testable import GlimbleCore

/// Helper: a frame of `n` fingers clustered at `center`, at time `t`.
private func frame(_ n: Int, at center: CGPoint, t: TimeInterval) -> TouchFrame {
    let fingers = (0..<n).map { i in
        Finger(id: Int32(i), position: center, pressure: 0.6)
    }
    return TouchFrame(fingers: fingers, timestamp: t)
}

@Test func threeFingerTapIsRecognizedOnLift() {
    var rec = GestureRecognizer()
    let c = CGPoint(x: 0.5, y: 0.5)
    #expect(rec.process(frame(3, at: c, t: 0.00)) == nil)
    #expect(rec.process(frame(3, at: c, t: 0.02)) == nil)
    let result = rec.process(TouchFrame(fingers: [], timestamp: 0.05))
    #expect(result == .tap(fingers: 3))
}

@Test func tapUsesMaxSimultaneousFingerCount() {
    var rec = GestureRecognizer()
    let c = CGPoint(x: 0.5, y: 0.5)
    _ = rec.process(frame(3, at: c, t: 0.00))
    _ = rec.process(frame(4, at: c, t: 0.01))
    let result = rec.process(TouchFrame(fingers: [], timestamp: 0.03))
    #expect(result == .tap(fingers: 4))
}
