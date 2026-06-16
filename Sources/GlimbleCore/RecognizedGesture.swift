/// A directional multi-finger swipe direction. Raw values are the JSON encoding.
public enum SwipeDirection: String, Codable, Equatable, Sendable, CaseIterable {
    case up, down, left, right
}

/// Zoom direction for a pinch gesture. Raw values are the JSON encoding.
public enum ZoomDirection: String, Codable, Equatable, Sendable, CaseIterable {
    case zoomIn = "in"
    case zoomOut = "out"
}

/// Rotation direction for a rotate gesture. Raw values are the JSON encoding.
public enum RotationDirection: String, Codable, Equatable, Sendable, CaseIterable {
    case clockwise = "cw"
    case counterclockwise = "ccw"
}

/// A gesture the recognizer can emit. Also serves as a rule's trigger (matched by equality),
/// so it is `Codable`.
public enum RecognizedGesture: Codable, Equatable, Sendable {
    case swipe(fingers: Int, direction: SwipeDirection)
    case tap(fingers: Int)
    case doubleTap(fingers: Int)
    case tripleTap(fingers: Int)
    case pinch(fingers: Int, zoom: ZoomDirection)
    case rotate(fingers: Int, direction: RotationDirection)
    case longPress(fingers: Int)
}
