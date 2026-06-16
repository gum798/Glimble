import Foundation

/// Combines two same-finger-count `.tap`s within a short window into a `.doubleTap`.
///
/// Pure and time-injected so it is unit-testable: the caller supplies `now` on every `input`
/// and drives `flush` from a timer. A first tap is only *held* (delaying its single-tap
/// delivery) when `shouldCombine(fingers)` is true — e.g. only when a double-tap rule exists
/// for that finger count, or while recording — so single taps stay latency-free otherwise.
public struct TapCombiner: Sendable {
    public var doubleTapWindow: TimeInterval = 0.3
    private var pending: (fingers: Int, deadline: TimeInterval)?

    public init() {}

    public var hasPending: Bool { pending != nil }
    public var pendingDeadline: TimeInterval? { pending?.deadline }

    /// Feed a recognized gesture at time `now`. Returns the gestures to deliver immediately
    /// (possibly empty if a first tap is being held, or two if a held tap is flushed alongside
    /// a passthrough gesture).
    public mutating func input(_ gesture: RecognizedGesture, now: TimeInterval,
                               shouldCombine: (Int) -> Bool) -> [RecognizedGesture] {
        guard case .tap(let n) = gesture else {
            // Non-tap (swipe / already-double): flush any held tap first, then pass it through.
            var out: [RecognizedGesture] = []
            if let p = takePending() { out.append(.tap(fingers: p.fingers)) }
            out.append(gesture)
            return out
        }
        // Second tap of the same count within the window → double tap.
        if let p = pending, p.fingers == n, now <= p.deadline {
            pending = nil
            return [.doubleTap(fingers: n)]
        }
        // Otherwise: flush any held (mismatched or expired) tap, then decide on this one.
        var out: [RecognizedGesture] = []
        if let p = takePending() { out.append(.tap(fingers: p.fingers)) }
        if shouldCombine(n) {
            pending = (n, now + doubleTapWindow)   // hold, awaiting a possible second tap
        } else {
            out.append(.tap(fingers: n))
        }
        return out
    }

    /// Emit a held tap whose window has expired (no second tap arrived). Drive from a timer.
    public mutating func flush(now: TimeInterval) -> [RecognizedGesture] {
        if let p = pending, now >= p.deadline {
            pending = nil
            return [.tap(fingers: p.fingers)]
        }
        return []
    }

    private mutating func takePending() -> (fingers: Int, deadline: TimeInterval)? {
        defer { pending = nil }
        return pending
    }
}
