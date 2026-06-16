import Testing
@testable import GlimbleCore

@Test func gestureDisplayNames() {
    #expect(RecognizedGesture.swipe(fingers: 3, direction: .left).displayName == "3-finger swipe left")
    #expect(RecognizedGesture.tap(fingers: 4).displayName == "4-finger tap")
}

@Test func actionDisplayNames() {
    #expect(GlimbleAction.window(.maximize).displayName == "Maximize window")
    #expect(GlimbleAction.shell("x").displayName == "Run shell command")
    #expect(GlimbleAction.launchApp(bundleID: "com.apple.Safari").displayName == "Launch com.apple.Safari")
}
