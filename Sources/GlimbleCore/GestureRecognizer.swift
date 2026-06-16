import CoreGraphics
import Foundation

/// Tunable thresholds (normalized 0…1 distance units).
public struct RecognizerConfig: Sendable {
    public var minFingers: Int = 2
    public var swipeMinDistance: CGFloat = 0.08
    public var tapMaxDistance: CGFloat = 0.03
    public var pinchMinSpread: CGFloat = 0.05
    public var rotateMinAngle: CGFloat = 0.35   // radians (~20°)
    public var longPressMin: TimeInterval = 0.5
    public var edgeThreshold: CGFloat = 0.06
    public var forceMinPressure: Float = 2.0    // hardware-dependent; tuned on-device later
    public var drawMinPathLength: CGFloat = 0.25
    public init() {}
}

/// Deterministic Layer-1 recognizer. Feed `TouchFrame`s in order; returns a `RecognizedGesture`
/// on the frame where a gesture completes (all fingers lift), else nil. Value type.
public struct GestureRecognizer: Sendable {
    public var config: RecognizerConfig

    private var active = false
    private var maxFingers = 0
    private var startCentroid: CGPoint = .zero
    private var peakCentroid: CGPoint = .zero   // centroid at the point of max displacement
    private var maxDisplacement: CGFloat = 0
    private var startSpread: CGFloat = 0
    private var spreadDelta: CGFloat = 0
    private var startAngles: [Int32: CGFloat] = [:]
    private var rotationDelta: CGFloat = 0
    private var maxPressure: Float = 0
    private var startTimestamp: TimeInterval = 0
    private var lastTimestamp: TimeInterval = 0
    private var path: [CGPoint] = []
    private let shapes = ShapeRecognizer()

    public init(config: RecognizerConfig = RecognizerConfig()) {
        self.config = config
    }

    public mutating func process(_ frame: TouchFrame) -> RecognizedGesture? {
        let touching = frame.fingerCount
        if !active {
            if touching >= config.minFingers {
                active = true
                maxFingers = touching
                startCentroid = frame.centroid
                peakCentroid = frame.centroid
                maxDisplacement = 0
                startSpread = spread(frame)
                spreadDelta = 0
                startAngles = anglesByID(frame)
                rotationDelta = 0
                maxPressure = 0
                startTimestamp = frame.timestamp
                path = [frame.centroid]
            }
            return nil
        }
        if touching > 0 {
            lastTimestamp = frame.timestamp
            if touching > maxFingers {
                // A new finger landed. Re-baseline so displacement measures only real movement
                // once the FULL finger count is down — the centroid shifts a lot as spread
                // fingers land one at a time, and that is not gesture movement (it would
                // otherwise misread a multi-finger tap as a swipe).
                maxFingers = touching
                startCentroid = frame.centroid
                peakCentroid = frame.centroid
                maxDisplacement = 0
                startSpread = spread(frame)
                spreadDelta = 0
                startAngles = anglesByID(frame)
                rotationDelta = 0
                maxPressure = 0
                startTimestamp = frame.timestamp
                path = [frame.centroid]
            } else if touching == maxFingers {
                // Measure displacement only while all fingers are down. Track the centroid at
                // peak displacement so a swipe that partially returns keeps its true direction.
                let d = distance(frame.centroid, startCentroid)
                if d > maxDisplacement {
                    maxDisplacement = d
                    peakCentroid = frame.centroid
                }
                let ds = spread(frame) - startSpread
                if abs(ds) > abs(spreadDelta) { spreadDelta = ds }
                let rot = averageRotation(frame)
                if abs(rot) > abs(rotationDelta) { rotationDelta = rot }
                maxPressure = max(maxPressure, frame.fingers.map(\.pressure).max() ?? 0)
                path.append(frame.centroid)
            }
            // touching < maxFingers: fingers are lifting; ignore (the centroid swing as fingers
            // leave is not movement either).
            return nil
        }
        let result = classify()
        reset()
        return result
    }

    private func classify() -> RecognizedGesture? {
        guard maxFingers >= config.minFingers else { return nil }
        if abs(rotationDelta) >= config.rotateMinAngle {
            return .rotate(fingers: maxFingers, direction: rotationDelta > 0 ? .counterclockwise : .clockwise)
        }
        if abs(spreadDelta) >= config.pinchMinSpread {
            return .pinch(fingers: maxFingers, zoom: spreadDelta > 0 ? .zoomIn : .zoomOut)
        }
        // Shape match only a genuinely CURVY path: a straight swipe has pathLen ~= maxDisplacement
        // and fails the 1.3x curvature gate, so it stays a swipe; a tap has a tiny path.
        let pathLen = polylineLength(path)
        if pathLen >= config.drawMinPathLength, pathLen > 1.3 * maxDisplacement,
           let shape = shapes.recognize(path) {
            return .draw(shape: shape)
        }
        if maxDisplacement >= config.swipeMinDistance {
            let dir = dominantDirection()
            if let edge = startEdge(for: dir) { return .edgeSwipe(fingers: maxFingers, edge: edge) }
            return .swipe(fingers: maxFingers, direction: dir)
        }
        if maxDisplacement <= config.tapMaxDistance {
            if maxPressure >= config.forceMinPressure { return .forceTouch(fingers: maxFingers) }
            if (lastTimestamp - startTimestamp) >= config.longPressMin {
                return .longPress(fingers: maxFingers)
            }
            return .tap(fingers: maxFingers)
        }
        return nil
    }

    /// The trackpad edge an inward swipe started from, if the session began within `edgeThreshold`
    /// of that edge AND the dominant direction moves inward from it; else nil (a normal swipe).
    private func startEdge(for dir: SwipeDirection) -> TrackpadEdge? {
        let t = config.edgeThreshold
        if startCentroid.x <= t && dir == .right { return .left }
        if startCentroid.x >= 1 - t && dir == .left { return .right }
        if startCentroid.y <= t && dir == .up { return .bottom }
        if startCentroid.y >= 1 - t && dir == .down { return .top }
        return nil
    }

    /// Direction of travel from session start to the point of MAX displacement (not the lift
    /// point), so a swipe that partially returns before lifting keeps its true direction. y is up.
    private func dominantDirection() -> SwipeDirection {
        let dx = peakCentroid.x - startCentroid.x
        let dy = peakCentroid.y - startCentroid.y
        if abs(dx) >= abs(dy) {
            return dx >= 0 ? .right : .left
        } else {
            return dy >= 0 ? .up : .down
        }
    }

    private mutating func reset() {
        // start/peak centroids are intentionally not cleared here: they are only read while
        // `active`, and `process` overwrites both when the next session begins.
        active = false
        maxFingers = 0
        maxDisplacement = 0
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x, dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Total length of the polyline through `pts` (sum of consecutive segment lengths).
    private func polylineLength(_ pts: [CGPoint]) -> CGFloat {
        guard pts.count > 1 else { return 0 }
        var total: CGFloat = 0
        for i in 1..<pts.count { total += distance(pts[i - 1], pts[i]) }
        return total
    }

    /// Average distance of the fingers from the centroid — grows on spread, shrinks on pinch.
    private func spread(_ frame: TouchFrame) -> CGFloat {
        guard frame.fingers.count > 1 else { return 0 }
        let c = frame.centroid
        let total = frame.fingers.reduce(CGFloat(0)) { $0 + distance($1.position, c) }
        return total / CGFloat(frame.fingers.count)
    }

    /// Angle of each finger about the cluster centroid (radians), keyed by finger id.
    /// Fingers essentially AT the centroid (radius ~0, e.g. a coincident tap/swipe cluster)
    /// carry no reliable angle — `atan2` on two near-zero deltas is pure rounding noise — so
    /// they are skipped. Only fingers with real lever-arm about the center define rotation.
    private func anglesByID(_ frame: TouchFrame) -> [Int32: CGFloat] {
        let c = frame.centroid
        var r: [Int32: CGFloat] = [:]
        for f in frame.fingers {
            let dx = f.position.x - c.x, dy = f.position.y - c.y
            if (dx * dx + dy * dy).squareRoot() < 1e-6 { continue }
            r[f.id] = atan2(dy, dx)
        }
        return r
    }

    /// Mean signed angular change (wrapped to ±π) of the fingers shared with the baseline frame.
    private func averageRotation(_ frame: TouchFrame) -> CGFloat {
        let now = anglesByID(frame); var sum: CGFloat = 0; var n = 0
        for (id, start) in startAngles { if let cur = now[id] { sum += atan2(sin(cur - start), cos(cur - start)); n += 1 } }
        return n > 0 ? sum / CGFloat(n) : 0
    }
}
