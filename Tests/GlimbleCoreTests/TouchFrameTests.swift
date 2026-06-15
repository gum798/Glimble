import Testing
import CoreGraphics
@testable import GlimbleCore

@Test func centroidAveragesFingerPositions() {
    let frame = TouchFrame(fingers: [
        Finger(id: 1, position: CGPoint(x: 0.2, y: 0.4), pressure: 0.5),
        Finger(id: 2, position: CGPoint(x: 0.4, y: 0.8), pressure: 0.5),
    ], timestamp: 1.0)
    #expect(abs(frame.centroid.x - 0.3) < 1e-9)
    #expect(abs(frame.centroid.y - 0.6) < 1e-9)
    #expect(frame.fingerCount == 2)
}

@Test func centroidOfEmptyFrameIsZeroAndCountZero() {
    let frame = TouchFrame(fingers: [], timestamp: 0)
    #expect(frame.fingerCount == 0)
    #expect(frame.centroid == .zero)
}
