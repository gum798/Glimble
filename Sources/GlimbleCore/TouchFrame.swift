import CoreGraphics
import Foundation

/// One active finger on the trackpad. Position is normalized 0…1, y increasing upward.
public struct Finger: Equatable, Sendable {
    public let id: Int32
    public let position: CGPoint
    public let pressure: Float

    public init(id: Int32, position: CGPoint, pressure: Float) {
        self.id = id
        self.position = position
        self.pressure = pressure
    }
}

/// A single multitouch frame: the set of fingers currently touching, plus a timestamp (seconds).
public struct TouchFrame: Equatable, Sendable {
    public let fingers: [Finger]
    public let timestamp: TimeInterval

    public init(fingers: [Finger], timestamp: TimeInterval) {
        self.fingers = fingers
        self.timestamp = timestamp
    }

    public var fingerCount: Int { fingers.count }

    /// Average finger position; `.zero` when there are no fingers.
    public var centroid: CGPoint {
        guard !fingers.isEmpty else { return .zero }
        let sum = fingers.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.position.x, y: $0.y + $1.position.y) }
        return CGPoint(x: sum.x / CGFloat(fingers.count), y: sum.y / CGFloat(fingers.count))
    }
}
