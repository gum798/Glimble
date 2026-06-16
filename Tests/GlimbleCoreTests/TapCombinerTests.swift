import Testing
import Foundation
@testable import GlimbleCore

private let never: @Sendable (Int, Int) -> Bool = { _, _ in false }
private let always: @Sendable (Int, Int) -> Bool = { _, _ in true }
private let wantsDouble: @Sendable (Int, Int) -> Bool = { _, c in c == 1 }   // reach 2 only
private let wantsTriple: @Sendable (Int, Int) -> Bool = { _, c in c <= 2 }   // reach 3

@Test func singleTapNoMultiRuleFiresImmediately() {
    var c = TapCombiner()
    #expect(c.input(.tap(fingers: 2), now: 1.0, wantsMore: never) == [.tap(fingers: 2)])
    #expect(!c.hasPending)
}

@Test func twoTapsBecomeDoubleWhenOnlyDoubleWanted() {
    var c = TapCombiner()
    #expect(c.input(.tap(fingers: 3), now: 1.0, wantsMore: wantsDouble).isEmpty)
    #expect(c.input(.tap(fingers: 3), now: 1.1, wantsMore: wantsDouble) == [.doubleTap(fingers: 3)])
    #expect(!c.hasPending)
}

@Test func threeTapsBecomeTripleWhenTripleWanted() {
    var c = TapCombiner()
    #expect(c.input(.tap(fingers: 3), now: 1.0, wantsMore: wantsTriple).isEmpty)
    #expect(c.input(.tap(fingers: 3), now: 1.1, wantsMore: wantsTriple).isEmpty)
    #expect(c.input(.tap(fingers: 3), now: 1.2, wantsMore: wantsTriple) == [.tripleTap(fingers: 3)])
}

@Test func doubleFlushesWhenThirdNeverComes() {
    var c = TapCombiner()
    _ = c.input(.tap(fingers: 3), now: 1.0, wantsMore: wantsTriple)
    _ = c.input(.tap(fingers: 3), now: 1.1, wantsMore: wantsTriple)
    #expect(c.flush(now: 1.45) == [.doubleTap(fingers: 3)])
}

@Test func singleFlushesWhenSecondNeverComes() {
    var c = TapCombiner()
    _ = c.input(.tap(fingers: 3), now: 1.0, wantsMore: wantsDouble)
    #expect(c.flush(now: 1.31) == [.tap(fingers: 3)])
}

@Test func capsAtTripleEvenIfMoreWanted() {
    var c = TapCombiner()
    _ = c.input(.tap(fingers: 3), now: 1.0, wantsMore: always)
    _ = c.input(.tap(fingers: 3), now: 1.1, wantsMore: always)
    #expect(c.input(.tap(fingers: 3), now: 1.2, wantsMore: always) == [.tripleTap(fingers: 3)])
    #expect(!c.hasPending)
}

@Test func differentFingerCountFlushesPrevious() {
    var c = TapCombiner()
    _ = c.input(.tap(fingers: 3), now: 1.0, wantsMore: wantsDouble)
    #expect(c.input(.tap(fingers: 4), now: 1.1, wantsMore: never) == [.tap(fingers: 3), .tap(fingers: 4)])
}

@Test func swipePassesThroughAndFlushesPending() {
    var c = TapCombiner()
    _ = c.input(.tap(fingers: 3), now: 1.0, wantsMore: wantsDouble)
    let out = c.input(.swipe(fingers: 3, direction: .left), now: 1.1, wantsMore: wantsDouble)
    #expect(out == [.tap(fingers: 3), .swipe(fingers: 3, direction: .left)])
}

@Test func secondTapAfterWindowStartsFresh() {
    var c = TapCombiner()
    _ = c.input(.tap(fingers: 3), now: 1.0, wantsMore: wantsDouble)
    #expect(c.input(.tap(fingers: 3), now: 1.5, wantsMore: wantsDouble) == [.tap(fingers: 3)])
    #expect(c.hasPending)
}
