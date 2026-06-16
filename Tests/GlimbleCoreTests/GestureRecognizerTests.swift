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

@Test func threeFingerSwipeLeftIsRecognized() {
    var rec = GestureRecognizer()
    _ = rec.process(frame(3, at: CGPoint(x: 0.7, y: 0.5), t: 0.00))
    _ = rec.process(frame(3, at: CGPoint(x: 0.45, y: 0.5), t: 0.02))
    _ = rec.process(frame(3, at: CGPoint(x: 0.2, y: 0.5), t: 0.04))
    let result = rec.process(TouchFrame(fingers: [], timestamp: 0.06))
    #expect(result == .swipe(fingers: 3, direction: .left))
}

@Test func fourFingerSwipeUpIsRecognized() {
    var rec = GestureRecognizer()
    _ = rec.process(frame(4, at: CGPoint(x: 0.5, y: 0.3), t: 0.00))
    _ = rec.process(frame(4, at: CGPoint(x: 0.5, y: 0.8), t: 0.03))
    let result = rec.process(TouchFrame(fingers: [], timestamp: 0.05))
    #expect(result == .swipe(fingers: 4, direction: .up))
}

@Test func dominantAxisDecidesDirection() {
    var rec = GestureRecognizer()
    _ = rec.process(frame(3, at: CGPoint(x: 0.3, y: 0.5), t: 0.00))
    _ = rec.process(frame(3, at: CGPoint(x: 0.7, y: 0.6), t: 0.03))
    let result = rec.process(TouchFrame(fingers: [], timestamp: 0.05))
    #expect(result == .swipe(fingers: 3, direction: .right))
}

@Test func oneFingerMovementIsIgnored() {
    var rec = GestureRecognizer()
    _ = rec.process(frame(1, at: CGPoint(x: 0.2, y: 0.5), t: 0.00))
    _ = rec.process(frame(1, at: CGPoint(x: 0.8, y: 0.5), t: 0.03))
    let result = rec.process(TouchFrame(fingers: [], timestamp: 0.05))
    #expect(result == nil)
}

@Test func ambiguousDistanceProducesNothing() {
    var rec = GestureRecognizer()
    _ = rec.process(frame(3, at: CGPoint(x: 0.50, y: 0.5), t: 0.00))
    _ = rec.process(frame(3, at: CGPoint(x: 0.55, y: 0.5), t: 0.03))
    let result = rec.process(TouchFrame(fingers: [], timestamp: 0.05))
    #expect(result == nil)
}

@Test func recognizerResetsBetweenGestures() {
    var rec = GestureRecognizer()
    let c = CGPoint(x: 0.5, y: 0.5)
    _ = rec.process(frame(2, at: c, t: 0.0))
    #expect(rec.process(TouchFrame(fingers: [], timestamp: 0.02)) == .tap(fingers: 2))
    _ = rec.process(frame(3, at: c, t: 1.0))
    #expect(rec.process(TouchFrame(fingers: [], timestamp: 1.02)) == .tap(fingers: 3))
}
