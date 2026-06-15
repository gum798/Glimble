import Testing
import Foundation
@testable import GlimbleCore

@Test func gestureEquality() {
    #expect(RecognizedGesture.tap(fingers: 3) == RecognizedGesture.tap(fingers: 3))
    #expect(RecognizedGesture.swipe(fingers: 3, direction: .left) != RecognizedGesture.swipe(fingers: 3, direction: .right))
}

@Test func gestureRoundTripsThroughJSON() throws {
    let gestures: [RecognizedGesture] = [
        .swipe(fingers: 4, direction: .up),
        .tap(fingers: 2),
    ]
    let data = try JSONEncoder().encode(gestures)
    let decoded = try JSONDecoder().decode([RecognizedGesture].self, from: data)
    #expect(decoded == gestures)
}
