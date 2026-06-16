import Testing
import CoreGraphics
import Foundation
@testable import GlimbleCore

/// A synthetic circle: `n` samples of `radius` about `center`.
private func circlePath(n: Int = 24, radius: CGFloat = 0.2, center: CGPoint = CGPoint(x: 0.5, y: 0.5)) -> [CGPoint] {
    (0..<n).map { i in
        let a = 2 * Double.pi * Double(i) / Double(n)
        return CGPoint(x: center.x + radius * CGFloat(cos(a)), y: center.y + radius * CGFloat(sin(a)))
    }
}

/// Sample a polyline (list of corner points) into `perSegment` points per segment.
private func densePolyline(_ corners: [CGPoint], perSegment: Int = 16) -> [CGPoint] {
    var out: [CGPoint] = []
    for i in 0..<(corners.count - 1) {
        let a = corners[i], b = corners[i + 1]
        for s in 0..<perSegment {
            let t = CGFloat(s) / CGFloat(perSegment)
            out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
        }
    }
    out.append(corners.last!)
    return out
}

@Test func recognizesCircle() {
    let r = ShapeRecognizer()
    #expect(r.recognize(circlePath()) == .circle)
}

@Test func recognizesCheck() {
    let r = ShapeRecognizer()
    let pts = densePolyline([CGPoint(x: 0, y: 0.5), CGPoint(x: 0.35, y: 0), CGPoint(x: 1, y: 1)])
    #expect(r.recognize(pts) == .check)
}

@Test func recognizesCaretUp() {
    let r = ShapeRecognizer()
    let pts = densePolyline([CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 1), CGPoint(x: 1, y: 0)])
    #expect(r.recognize(pts) == .caretUp)
}

@Test func recognizesCaretDown() {
    let r = ShapeRecognizer()
    let pts = densePolyline([CGPoint(x: 0, y: 1), CGPoint(x: 0.5, y: 0), CGPoint(x: 1, y: 1)])
    #expect(r.recognize(pts) == .caretDown)
}

@Test func tinyPathIsNil() {
    let r = ShapeRecognizer()
    #expect(r.recognize([CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5001, y: 0.5)]) == nil)
}

@Test func tooFewPointsIsNil() {
    let r = ShapeRecognizer()
    #expect(r.recognize([CGPoint(x: 0.5, y: 0.5)]) == nil)
    #expect(r.recognize([]) == nil)
}

@Test func straightLineIsNotACircle() {
    let r = ShapeRecognizer()
    let line = densePolyline([CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0)])
    // A straight line is degenerate (zero-area bounding box in one axis); must not be a circle.
    #expect(r.recognize(line) != .circle)
}

// A circle and a caret are visually distinct; the recognizer must not confuse them.
@Test func circleAndCaretDoNotCollide() {
    let r = ShapeRecognizer()
    #expect(r.recognize(circlePath()) == .circle)
    let caret = densePolyline([CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 1), CGPoint(x: 1, y: 0)])
    #expect(r.recognize(caret) == .caretUp)
}
