/// A directional multi-finger swipe direction. Raw values are the JSON encoding.
public enum SwipeDirection: String, Codable, Equatable, Sendable, CaseIterable {
    case up, down, left, right
}

/// A gesture the recognizer can emit. Also serves as a rule's trigger (matched by equality),
/// so it is `Codable`.
public enum RecognizedGesture: Codable, Equatable, Sendable {
    case swipe(fingers: Int, direction: SwipeDirection)
    case tap(fingers: Int)
    case doubleTap(fingers: Int)
}
