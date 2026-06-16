import Testing
import Foundation
@testable import GlimbleCore

private func always(_ n: Int) -> Bool { true }
private func never(_ n: Int) -> Bool { false }

@Test func twoTapsWithinWindowBecomeDoubleTap() {
    var c = TapCombiner()   // default window 0.3
    #expect(c.input(.tap(fingers: 3), now: 1.0, shouldCombine: always).isEmpty)  // first held
    #expect(c.input(.tap(fingers: 3), now: 1.1, shouldCombine: always) == [.doubleTap(fingers: 3)])
    #expect(!c.hasPending)
}

@Test func singleTapFlushesAfterWindow() {
    var c = TapCombiner()
    _ = c.input(.tap(fingers: 3), now: 1.0, shouldCombine: always)
    #expect(c.hasPending)
    #expect(c.flush(now: 1.31) == [.tap(fingers: 3)])
    #expect(!c.hasPending)
}

@Test func flushBeforeDeadlineEmitsNothing() {
    var c = TapCombiner()
    _ = c.input(.tap(fingers: 3), now: 1.0, shouldCombine: always)
    #expect(c.flush(now: 1.1).isEmpty)
    #expect(c.hasPending)
}

@Test func nonCombiningTapPassesThroughImmediately() {
    var c = TapCombiner()
    #expect(c.input(.tap(fingers: 2), now: 1.0, shouldCombine: never) == [.tap(fingers: 2)])
    #expect(!c.hasPending)
}

@Test func differentFingerCountFlushesFirstTap() {
    var c = TapCombiner()
    _ = c.input(.tap(fingers: 3), now: 1.0, shouldCombine: always)
    #expect(c.input(.tap(fingers: 4), now: 1.1, shouldCombine: always) == [.tap(fingers: 3)])
    #expect(c.hasPending)   // the 4-finger tap is now pending
}

@Test func swipePassesThroughAndFlushesPendingTap() {
    var c = TapCombiner()
    _ = c.input(.tap(fingers: 3), now: 1.0, shouldCombine: always)
    let out = c.input(.swipe(fingers: 3, direction: .left), now: 1.1, shouldCombine: always)
    #expect(out == [.tap(fingers: 3), .swipe(fingers: 3, direction: .left)])
    #expect(!c.hasPending)
}

@Test func secondTapAfterWindowIsNotDouble() {
    var c = TapCombiner()
    _ = c.input(.tap(fingers: 3), now: 1.0, shouldCombine: always)
    #expect(c.input(.tap(fingers: 3), now: 1.5, shouldCombine: always) == [.tap(fingers: 3)])
    #expect(c.hasPending)   // first flushed; second held as a fresh pending
}
