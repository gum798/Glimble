import Foundation

/// Combines repeated same-finger-count `.tap`s within a short window into `.doubleTap` / `.tripleTap`.
/// Pure + time-injected. `wantsMore(fingers, currentCount)` decides whether to keep holding for one
/// more tap (e.g. a double-tap rule wants to reach 2; a triple-tap rule wants to reach 3; recording
/// wants all). Caps at triple. Holding only happens when wanted, so plain taps stay latency-free.
public struct TapCombiner: Sendable {
    public var doubleTapWindow: TimeInterval = 0.3
    private var pending: (fingers: Int, count: Int, deadline: TimeInterval)?

    public init() {}

    public var hasPending: Bool { pending != nil }
    public var pendingDeadline: TimeInterval? { pending?.deadline }

    public mutating func input(_ gesture: RecognizedGesture, now: TimeInterval,
                               wantsMore: (Int, Int) -> Bool) -> [RecognizedGesture] {
        guard case .tap(let n) = gesture else {
            var out: [RecognizedGesture] = []
            if let p = take() { out.append(gestureFor(p.count, p.fingers)) }
            out.append(gesture)
            return out
        }
        // Continuing a multi-tap of the same finger count within the window.
        if let p = pending, p.fingers == n, now <= p.deadline {
            let count = p.count + 1
            if count >= 3 { pending = nil; return [gestureFor(3, n)] }      // cap at triple
            if wantsMore(n, count) { pending = (n, count, now + doubleTapWindow); return [] }
            pending = nil
            return [gestureFor(count, n)]
        }
        // A fresh tap: flush any held tap, then hold this one only if more are wanted.
        var out: [RecognizedGesture] = []
        if let p = take() { out.append(gestureFor(p.count, p.fingers)) }
        if wantsMore(n, 1) {
            pending = (n, 1, now + doubleTapWindow)
        } else {
            out.append(.tap(fingers: n))
        }
        return out
    }

    /// Emit a held tap-run whose window expired. Drive from a timer.
    public mutating func flush(now: TimeInterval) -> [RecognizedGesture] {
        if let p = pending, now >= p.deadline { pending = nil; return [gestureFor(p.count, p.fingers)] }
        return []
    }

    private func gestureFor(_ count: Int, _ fingers: Int) -> RecognizedGesture {
        switch count {
        case 1: return .tap(fingers: fingers)
        case 2: return .doubleTap(fingers: fingers)
        default: return .tripleTap(fingers: fingers)
        }
    }

    private mutating func take() -> (fingers: Int, count: Int, deadline: TimeInterval)? {
        defer { pending = nil }
        return pending
    }
}
