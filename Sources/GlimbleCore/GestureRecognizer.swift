import CoreGraphics

/// Tunable thresholds (normalized 0…1 distance units).
public struct RecognizerConfig: Sendable {
    public var minFingers: Int = 2
    public var swipeMinDistance: CGFloat = 0.08
    public var tapMaxDistance: CGFloat = 0.03
    public init() {}
}

/// Deterministic Layer-1 recognizer. Feed `TouchFrame`s in order; returns a `RecognizedGesture`
/// on the frame where a gesture completes (all fingers lift), else nil. Value type.
public struct GestureRecognizer: Sendable {
    public var config: RecognizerConfig

    private var active = false
    private var maxFingers = 0
    private var startCentroid: CGPoint = .zero
    private var lastCentroid: CGPoint = .zero
    private var maxDisplacement: CGFloat = 0

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
                lastCentroid = frame.centroid
                maxDisplacement = 0
            }
            return nil
        }
        if touching > 0 {
            maxFingers = max(maxFingers, touching)
            lastCentroid = frame.centroid
            maxDisplacement = max(maxDisplacement, distance(frame.centroid, startCentroid))
            return nil
        }
        let result = classify()
        reset()
        return result
    }

    private func classify() -> RecognizedGesture? {
        guard maxFingers >= config.minFingers else { return nil }
        if maxDisplacement >= config.swipeMinDistance {
            return .swipe(fingers: maxFingers, direction: dominantDirection())
        }
        if maxDisplacement <= config.tapMaxDistance {
            return .tap(fingers: maxFingers)
        }
        return nil
    }

    /// Direction of net travel from session start to last touching frame. y is up.
    private func dominantDirection() -> SwipeDirection {
        let dx = lastCentroid.x - startCentroid.x
        let dy = lastCentroid.y - startCentroid.y
        if abs(dx) >= abs(dy) {
            return dx >= 0 ? .right : .left
        } else {
            return dy >= 0 ? .up : .down
        }
    }

    private mutating func reset() {
        active = false
        maxFingers = 0
        maxDisplacement = 0
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x, dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
