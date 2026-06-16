import CoreGraphics

/// Tunable thresholds (normalized 0…1 distance units).
public struct RecognizerConfig: Sendable {
    public var minFingers: Int = 2
    public var swipeMinDistance: CGFloat = 0.08
    public var tapMaxDistance: CGFloat = 0.03
    public var pinchMinSpread: CGFloat = 0.05
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
            }
            return nil
        }
        if touching > 0 {
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
        if abs(spreadDelta) >= config.pinchMinSpread {
            return .pinch(fingers: maxFingers, zoom: spreadDelta > 0 ? .zoomIn : .zoomOut)
        }
        if maxDisplacement >= config.swipeMinDistance {
            return .swipe(fingers: maxFingers, direction: dominantDirection())
        }
        if maxDisplacement <= config.tapMaxDistance {
            return .tap(fingers: maxFingers)
        }
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

    /// Average distance of the fingers from the centroid — grows on spread, shrinks on pinch.
    private func spread(_ frame: TouchFrame) -> CGFloat {
        guard frame.fingers.count > 1 else { return 0 }
        let c = frame.centroid
        let total = frame.fingers.reduce(CGFloat(0)) { $0 + distance($1.position, c) }
        return total / CGFloat(frame.fingers.count)
    }
}
