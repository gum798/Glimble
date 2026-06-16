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

@Test func swipeAndReturnKeepsPeakDirection() {
    // Swipe right to the peak, then partially return left before lifting.
    // Net displacement at lift (x=0.45) is slightly LEFT of start (x=0.5), but the gesture
    // is clearly a rightward swipe — direction must come from the peak (x=0.9), not the lift.
    var rec = GestureRecognizer()
    _ = rec.process(frame(3, at: CGPoint(x: 0.5, y: 0.5), t: 0.00))
    _ = rec.process(frame(3, at: CGPoint(x: 0.9, y: 0.5), t: 0.02))   // peak: +0.4 right
    _ = rec.process(frame(3, at: CGPoint(x: 0.45, y: 0.5), t: 0.04))  // returns: net -0.05
    let result = rec.process(TouchFrame(fingers: [], timestamp: 0.06))
    #expect(result == .swipe(fingers: 3, direction: .right))
}

// Real hardware: fingers of a multi-finger tap land/lift one at a time, so the centroid
// swings DURING landing/lifting even though the user never "moves". That swing must NOT be
// counted as gesture movement, or taps get misread as swipes. (Regression: 3/4-finger tap.)

@Test func tapWithSpreadFingersLandingSequentiallyIsTap() {
    var rec = GestureRecognizer()
    let f0 = Finger(id: 0, position: CGPoint(x: 0.30, y: 0.5), pressure: 0.6)
    let f1 = Finger(id: 1, position: CGPoint(x: 0.50, y: 0.5), pressure: 0.6)
    let f2 = Finger(id: 2, position: CGPoint(x: 0.70, y: 0.5), pressure: 0.6)
    _ = rec.process(TouchFrame(fingers: [f0], timestamp: 0.00))             // 1 finger, centroid 0.30
    _ = rec.process(TouchFrame(fingers: [f0, f1], timestamp: 0.01))         // 2 fingers, centroid 0.40
    _ = rec.process(TouchFrame(fingers: [f0, f1, f2], timestamp: 0.02))     // 3 fingers, centroid 0.50
    _ = rec.process(TouchFrame(fingers: [f0, f1, f2], timestamp: 0.03))     // held
    let result = rec.process(TouchFrame(fingers: [], timestamp: 0.05))      // lift
    #expect(result == .tap(fingers: 3))
}

@Test func tapWithSpreadFingersLiftingSequentiallyIsTap() {
    var rec = GestureRecognizer()
    let f0 = Finger(id: 0, position: CGPoint(x: 0.30, y: 0.5), pressure: 0.6)
    let f1 = Finger(id: 1, position: CGPoint(x: 0.70, y: 0.5), pressure: 0.6)
    _ = rec.process(TouchFrame(fingers: [f0, f1], timestamp: 0.00))   // 2 fingers, centroid 0.50
    _ = rec.process(TouchFrame(fingers: [f0, f1], timestamp: 0.01))   // held
    _ = rec.process(TouchFrame(fingers: [f0], timestamp: 0.02))       // f1 lifts → centroid 0.30 (ignore)
    let result = rec.process(TouchFrame(fingers: [], timestamp: 0.03))
    #expect(result == .tap(fingers: 2))
}

@Test func threeFingerSpreadIsZoomIn() {
    // Two fingers move apart horizontally around a fixed center; the 3rd stays put.
    // Centroid fixed (0.5,0.5) so it's not a swipe; spread grows → zoom in.
    var rec = GestureRecognizer()
    let close = [Finger(id: 0, position: CGPoint(x: 0.4, y: 0.5), pressure: 0.6),
                 Finger(id: 1, position: CGPoint(x: 0.6, y: 0.5), pressure: 0.6),
                 Finger(id: 2, position: CGPoint(x: 0.5, y: 0.5), pressure: 0.6)]
    let wide  = [Finger(id: 0, position: CGPoint(x: 0.2, y: 0.5), pressure: 0.6),
                 Finger(id: 1, position: CGPoint(x: 0.8, y: 0.5), pressure: 0.6),
                 Finger(id: 2, position: CGPoint(x: 0.5, y: 0.5), pressure: 0.6)]
    _ = rec.process(TouchFrame(fingers: close, timestamp: 0.0))
    _ = rec.process(TouchFrame(fingers: wide, timestamp: 0.03))
    #expect(rec.process(TouchFrame(fingers: [], timestamp: 0.05)) == .pinch(fingers: 3, zoom: .zoomIn))
}

@Test func threeFingerPinchIsZoomOut() {
    var rec = GestureRecognizer()
    let wide  = [Finger(id: 0, position: CGPoint(x: 0.2, y: 0.5), pressure: 0.6),
                 Finger(id: 1, position: CGPoint(x: 0.8, y: 0.5), pressure: 0.6),
                 Finger(id: 2, position: CGPoint(x: 0.5, y: 0.5), pressure: 0.6)]
    let close = [Finger(id: 0, position: CGPoint(x: 0.4, y: 0.5), pressure: 0.6),
                 Finger(id: 1, position: CGPoint(x: 0.6, y: 0.5), pressure: 0.6),
                 Finger(id: 2, position: CGPoint(x: 0.5, y: 0.5), pressure: 0.6)]
    _ = rec.process(TouchFrame(fingers: wide, timestamp: 0.0))
    _ = rec.process(TouchFrame(fingers: close, timestamp: 0.03))
    #expect(rec.process(TouchFrame(fingers: [], timestamp: 0.05)) == .pinch(fingers: 3, zoom: .zoomOut))
}

@Test func threeFingerTranslationIsSwipeNotPinch() {
    // Fixed formation translating right: spread constant → not a pinch; centroid moves → swipe.
    var rec = GestureRecognizer()
    func formation(_ dx: CGFloat) -> [Finger] {
        [Finger(id: 0, position: CGPoint(x: 0.2 + dx, y: 0.5), pressure: 0.6),
         Finger(id: 1, position: CGPoint(x: 0.3 + dx, y: 0.5), pressure: 0.6),
         Finger(id: 2, position: CGPoint(x: 0.25 + dx, y: 0.6), pressure: 0.6)]
    }
    _ = rec.process(TouchFrame(fingers: formation(0), timestamp: 0.0))
    _ = rec.process(TouchFrame(fingers: formation(0.4), timestamp: 0.03))
    #expect(rec.process(TouchFrame(fingers: [], timestamp: 0.05)) == .swipe(fingers: 3, direction: .right))
}

@Test func twoFingerRotationIsRotate() {
    var rec = GestureRecognizer()
    func a(_ p: CGPoint) -> Finger { Finger(id: 0, position: p, pressure: 0.6) }
    func b(_ p: CGPoint) -> Finger { Finger(id: 1, position: p, pressure: 0.6) }
    _ = rec.process(TouchFrame(fingers: [a(CGPoint(x:0.3,y:0.5)), b(CGPoint(x:0.7,y:0.5))], timestamp: 0))
    _ = rec.process(TouchFrame(fingers: [a(CGPoint(x:0.5,y:0.3)), b(CGPoint(x:0.5,y:0.7))], timestamp: 0.03))
    #expect(rec.process(TouchFrame(fingers: [], timestamp: 0.05)) == .rotate(fingers: 2, direction: .counterclockwise))
}

@Test func heldStillBeyondThresholdIsLongPress() {
    var rec = GestureRecognizer()
    let c = CGPoint(x: 0.5, y: 0.5)
    _ = rec.process(frame(3, at: c, t: 0.0))
    _ = rec.process(frame(3, at: c, t: 0.6))
    #expect(rec.process(TouchFrame(fingers: [], timestamp: 0.61)) == .longPress(fingers: 3))
}

@Test func quickStillTapStaysTap() {
    var rec = GestureRecognizer()
    let c = CGPoint(x: 0.5, y: 0.5)
    _ = rec.process(frame(3, at: c, t: 0.0))
    _ = rec.process(frame(3, at: c, t: 0.1))
    #expect(rec.process(TouchFrame(fingers: [], timestamp: 0.11)) == .tap(fingers: 3))
}

// Explicit gates: a real translation (spread fingers, lever-arm present) and a real pinch
// must NOT be misread as rotate — the rotate check runs first, so these pin that boundary.

@Test func translationWithSpreadFingersIsSwipeNotRotate() {
    var rec = GestureRecognizer()
    func form(_ dx: CGFloat) -> [Finger] {
        [Finger(id: 0, position: CGPoint(x: 0.2 + dx, y: 0.50), pressure: 0.6),
         Finger(id: 1, position: CGPoint(x: 0.3 + dx, y: 0.55), pressure: 0.6),
         Finger(id: 2, position: CGPoint(x: 0.25 + dx, y: 0.45), pressure: 0.6)]
    }
    _ = rec.process(TouchFrame(fingers: form(0), timestamp: 0))
    _ = rec.process(TouchFrame(fingers: form(0.4), timestamp: 0.03))
    #expect(rec.process(TouchFrame(fingers: [], timestamp: 0.05)) == .swipe(fingers: 3, direction: .right))
}

@Test func pinchIsZoomNotRotate() {
    var rec = GestureRecognizer()
    let close = [Finger(id: 0, position: CGPoint(x: 0.4, y: 0.5), pressure: 0.6),
                 Finger(id: 1, position: CGPoint(x: 0.6, y: 0.5), pressure: 0.6),
                 Finger(id: 2, position: CGPoint(x: 0.5, y: 0.5), pressure: 0.6)]
    let wide  = [Finger(id: 0, position: CGPoint(x: 0.2, y: 0.5), pressure: 0.6),
                 Finger(id: 1, position: CGPoint(x: 0.8, y: 0.5), pressure: 0.6),
                 Finger(id: 2, position: CGPoint(x: 0.5, y: 0.5), pressure: 0.6)]
    _ = rec.process(TouchFrame(fingers: close, timestamp: 0))
    _ = rec.process(TouchFrame(fingers: wide, timestamp: 0.03))
    #expect(rec.process(TouchFrame(fingers: [], timestamp: 0.05)) == .pinch(fingers: 3, zoom: .zoomIn))
}
