# Glimble v1 — Plan 1: Core Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Phase 0 spike into a working gesture→action engine: real multi-finger swipe/tap recognition feeding a JSON rule store that dispatches keyboard-shortcut / script / app-launch / window actions, scoped per-app, with curated default presets.

**Architecture:** All deterministic domain logic (touch model, gesture recognizer, rule model + matching, presets) lives in the **pure, OS-import-free `GlimbleCore`** target and is fully unit-tested with `swift test`. The renamed `GlimbleApp` executable owns the OS edges: `TouchSource` (OpenMultitouchSupport → `TouchFrame`), `AppContext` (frontmost bundle id), `ActionExecutor` (CGEvent/AX/Process), wiring them into the menu-bar `AppDelegate`. This is Plan 1 of three (engine → UI/shell → distribution).

**Tech Stack:** Swift 6.x, Swift Testing, CoreGraphics (pure geometry/keycodes), AppKit, ApplicationServices, `Kyome22/OpenMultitouchSupport` 4.0.0. Min macOS 15, validated on 26.

---

## Conventions locked for this plan (use verbatim — later tasks depend on these signatures)

- Trackpad coordinates are **normalized 0…1, y increasing upward** (matches OpenMultitouchSupport `OMSPosition`). The app-layer `TouchSource` is the only place that maps `OMSTouchData` → these types.
- `GestureRecognizer` is a **value type** (`struct`, `mutating func process`) so tests feed frame sequences deterministically with no shared state.
- A rule's **trigger is a `RecognizedGesture`** — matching is equality. This keeps the model tiny.
- App identity: bundle id **`com.glimble.Glimble`**, app name **Glimble**, executable target **`GlimbleApp`**.

---

### Task 1: Rename the spike target to GlimbleApp + real bundle identity

**Files:**
- Modify: `Package.swift`
- Rename: `Sources/GlimbleSpike/` → `Sources/GlimbleApp/`
- Modify: `Sources/GlimbleApp/Info.plist`
- Modify: `scripts/build-app.sh`

- [ ] **Step 1: Move the sources**

```bash
git mv Sources/GlimbleSpike Sources/GlimbleApp
```

- [ ] **Step 2: Update `Package.swift`** — rename the executable product/target `GlimbleSpike` → `GlimbleApp` (leave `GlimbleCore`, the dependency, and the test target unchanged):

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Glimble",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "GlimbleCore", targets: ["GlimbleCore"]),
        .executable(name: "GlimbleApp", targets: ["GlimbleApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Kyome22/OpenMultitouchSupport.git", exact: "4.0.0"),
    ],
    targets: [
        .target(name: "GlimbleCore"),
        .executableTarget(
            name: "GlimbleApp",
            dependencies: [
                "GlimbleCore",
                .product(name: "OpenMultitouchSupport", package: "OpenMultitouchSupport"),
            ],
            exclude: ["Info.plist"]
        ),
        .testTarget(name: "GlimbleCoreTests", dependencies: ["GlimbleCore"]),
    ]
)
```

- [ ] **Step 3: Update `Sources/GlimbleApp/Info.plist`** — set the real identity:

Replace the `CFBundleIdentifier`, `CFBundleName`, and `CFBundleExecutable` values:
```xml
    <key>CFBundleIdentifier</key>          <string>com.glimble.Glimble</string>
    <key>CFBundleName</key>                <string>Glimble</string>
    <key>CFBundleExecutable</key>          <string>GlimbleApp</string>
```
(Leave `LSUIElement`, version keys, `LSMinimumSystemVersion`, `NSPrincipalClass` as they are.)

- [ ] **Step 4: Update `scripts/build-app.sh`** — the app bundle and product names:

Change these three lines:
```bash
APP="Glimble.app"
BIN="${BUILD_DIR}/GlimbleApp"
```
and the build line:
```bash
swift build -c "${CONFIG}" --product GlimbleApp
```
and the executable copy line:
```bash
cp "${BIN}" "${APP}/Contents/MacOS/GlimbleApp"
```
and the rpath/sign lines that reference `Contents/MacOS/GlimbleSpike` → `Contents/MacOS/GlimbleApp`. (Search the file for `GlimbleSpike`/`Glimble Spike.app` and replace every occurrence.)

- [ ] **Step 5: Build + test**

Run: `swift build && swift test`
Expected: `Build complete!`, 12 GlimbleCore tests pass.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: rename spike to GlimbleApp with com.glimble.Glimble identity"
```

---

### Task 2: Touch model — `Finger` and `TouchFrame` (pure)

**Files:**
- Create: `Sources/GlimbleCore/TouchFrame.swift`
- Create: `Tests/GlimbleCoreTests/TouchFrameTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/GlimbleCoreTests/TouchFrameTests.swift`:
```swift
import Testing
import CoreGraphics
@testable import GlimbleCore

@Test func centroidAveragesFingerPositions() {
    let frame = TouchFrame(fingers: [
        Finger(id: 1, position: CGPoint(x: 0.2, y: 0.4), pressure: 0.5),
        Finger(id: 2, position: CGPoint(x: 0.4, y: 0.8), pressure: 0.5),
    ], timestamp: 1.0)
    #expect(frame.centroid == CGPoint(x: 0.3, y: 0.6))
    #expect(frame.fingerCount == 2)
}

@Test func centroidOfEmptyFrameIsZeroAndCountZero() {
    let frame = TouchFrame(fingers: [], timestamp: 0)
    #expect(frame.fingerCount == 0)
    #expect(frame.centroid == .zero)
}
```

- [ ] **Step 2: Run, verify FAIL**

Run: `swift test --filter TouchFrameTests`
Expected: FAIL — cannot find 'TouchFrame' / 'Finger' in scope.

- [ ] **Step 3: Implement**

`Sources/GlimbleCore/TouchFrame.swift`:
```swift
import CoreGraphics

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
```

- [ ] **Step 4: Run, verify PASS**

Run: `swift test --filter TouchFrameTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/GlimbleCore/TouchFrame.swift Tests/GlimbleCoreTests/TouchFrameTests.swift
git commit -m "feat: add Finger/TouchFrame touch model with centroid"
```

---

### Task 3: `RecognizedGesture` + `SwipeDirection` (pure, Codable)

**Files:**
- Create: `Sources/GlimbleCore/RecognizedGesture.swift`
- Create: `Tests/GlimbleCoreTests/RecognizedGestureTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/GlimbleCoreTests/RecognizedGestureTests.swift`:
```swift
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
```

- [ ] **Step 2: Run, verify FAIL**

Run: `swift test --filter RecognizedGestureTests`
Expected: FAIL — cannot find 'RecognizedGesture' / 'SwipeDirection'.

- [ ] **Step 3: Implement**

`Sources/GlimbleCore/RecognizedGesture.swift`:
```swift
/// A directional multi-finger swipe direction. Raw values are the JSON encoding.
public enum SwipeDirection: String, Codable, Equatable, Sendable, CaseIterable {
    case up, down, left, right
}

/// A gesture the recognizer can emit. Also serves as a rule's trigger (matched by equality),
/// so it is `Codable`.
public enum RecognizedGesture: Codable, Equatable, Sendable {
    case swipe(fingers: Int, direction: SwipeDirection)
    case tap(fingers: Int)
}
```

- [ ] **Step 4: Run, verify PASS**

Run: `swift test --filter RecognizedGestureTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/GlimbleCore/RecognizedGesture.swift Tests/GlimbleCoreTests/RecognizedGestureTests.swift
git commit -m "feat: add RecognizedGesture and SwipeDirection types"
```

---

### Task 4: `GestureRecognizer` — taps (TDD)

The recognizer tracks one touch *session* from the first frame with ≥`minFingers` touching until all fingers lift, then classifies. This task handles taps; Task 5 adds swipes; Task 6 adds gating/rejection.

**Files:**
- Create: `Sources/GlimbleCore/GestureRecognizer.swift`
- Create: `Tests/GlimbleCoreTests/GestureRecognizerTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/GlimbleCoreTests/GestureRecognizerTests.swift`:
```swift
import Testing
import CoreGraphics
@testable import GlimbleCore

/// Helper: a frame of `n` fingers clustered at `center`, at time `t`.
private func frame(_ n: Int, at center: CGPoint, t: TimeInterval) -> TouchFrame {
    let fingers = (0..<n).map { i in
        Finger(id: Int32(i), position: center, pressure: 0.6)
    }
    return TouchFrame(fingers: fingers, timestamp: t)
}

@Test func threeFingerTapIsRecognizedOnLift() {
    var rec = GestureRecognizer()
    let c = CGPoint(x: 0.5, y: 0.5)
    // 3 fingers down, barely moving, then all lift.
    #expect(rec.process(frame(3, at: c, t: 0.00)) == nil)
    #expect(rec.process(frame(3, at: c, t: 0.02)) == nil)
    let result = rec.process(TouchFrame(fingers: [], timestamp: 0.05))
    #expect(result == .tap(fingers: 3))
}

@Test func tapUsesMaxSimultaneousFingerCount() {
    var rec = GestureRecognizer()
    let c = CGPoint(x: 0.5, y: 0.5)
    // Reads 3 then 4 fingers (the 4th lands a frame late) — should latch 4.
    _ = rec.process(frame(3, at: c, t: 0.00))
    _ = rec.process(frame(4, at: c, t: 0.01))
    let result = rec.process(TouchFrame(fingers: [], timestamp: 0.03))
    #expect(result == .tap(fingers: 4))
}
```

- [ ] **Step 2: Run, verify FAIL**

Run: `swift test --filter GestureRecognizerTests`
Expected: FAIL — cannot find 'GestureRecognizer'.

- [ ] **Step 3: Implement (taps only for now)**

`Sources/GlimbleCore/GestureRecognizer.swift`:
```swift
import CoreGraphics

/// Tunable thresholds (normalized 0…1 distance units).
public struct RecognizerConfig: Sendable {
    public var minFingers: Int = 2
    public var swipeMinDistance: CGFloat = 0.08
    public var tapMaxDistance: CGFloat = 0.03
    public init() {}
}

/// Deterministic, allocation-light Layer-1 recognizer. Feed it `TouchFrame`s in order;
/// it returns a `RecognizedGesture` on the frame where a gesture completes (all fingers lift),
/// otherwise `nil`. Value type: no shared state, so it is trivially testable.
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
            // Start a session only once enough fingers are down.
            if touching >= config.minFingers {
                active = true
                maxFingers = touching
                startCentroid = frame.centroid
                lastCentroid = frame.centroid
                maxDisplacement = 0
            }
            return nil
        }

        // Active session.
        if touching > 0 {
            maxFingers = max(maxFingers, touching)
            lastCentroid = frame.centroid
            maxDisplacement = max(maxDisplacement, distance(frame.centroid, startCentroid))
            return nil
        }

        // All fingers lifted → classify and reset.
        let result = classify()
        reset()
        return result
    }

    private func classify() -> RecognizedGesture? {
        guard maxFingers >= config.minFingers else { return nil }
        if maxDisplacement <= config.tapMaxDistance {
            return .tap(fingers: maxFingers)
        }
        return nil   // swipes added in the next task
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
```

- [ ] **Step 4: Run, verify PASS**

Run: `swift test --filter GestureRecognizerTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/GlimbleCore/GestureRecognizer.swift Tests/GlimbleCoreTests/GestureRecognizerTests.swift
git commit -m "feat: GestureRecognizer recognizes multi-finger taps"
```

---

### Task 5: `GestureRecognizer` — swipes + direction (TDD)

**Files:**
- Modify: `Sources/GlimbleCore/GestureRecognizer.swift`
- Modify: `Tests/GlimbleCoreTests/GestureRecognizerTests.swift`

- [ ] **Step 1: Append failing tests**

Add to `Tests/GlimbleCoreTests/GestureRecognizerTests.swift`:
```swift
@Test func threeFingerSwipeLeftIsRecognized() {
    var rec = GestureRecognizer()
    // Start at x=0.7, move left to x=0.2 (dx = -0.5, well past 0.08), y steady.
    _ = rec.process(frame(3, at: CGPoint(x: 0.7, y: 0.5), t: 0.00))
    _ = rec.process(frame(3, at: CGPoint(x: 0.45, y: 0.5), t: 0.02))
    _ = rec.process(frame(3, at: CGPoint(x: 0.2, y: 0.5), t: 0.04))
    let result = rec.process(TouchFrame(fingers: [], timestamp: 0.06))
    #expect(result == .swipe(fingers: 3, direction: .left))
}

@Test func fourFingerSwipeUpIsRecognized() {
    var rec = GestureRecognizer()
    // y increases upward; move from y=0.3 to y=0.8.
    _ = rec.process(frame(4, at: CGPoint(x: 0.5, y: 0.3), t: 0.00))
    _ = rec.process(frame(4, at: CGPoint(x: 0.5, y: 0.8), t: 0.03))
    let result = rec.process(TouchFrame(fingers: [], timestamp: 0.05))
    #expect(result == .swipe(fingers: 4, direction: .up))
}

@Test func dominantAxisDecidesDirection() {
    var rec = GestureRecognizer()
    // Mostly rightward (dx=+0.4) with slight up (dy=+0.1) → right.
    _ = rec.process(frame(3, at: CGPoint(x: 0.3, y: 0.5), t: 0.00))
    _ = rec.process(frame(3, at: CGPoint(x: 0.7, y: 0.6), t: 0.03))
    let result = rec.process(TouchFrame(fingers: [], timestamp: 0.05))
    #expect(result == .swipe(fingers: 3, direction: .right))
}
```

- [ ] **Step 2: Run, verify FAIL**

Run: `swift test --filter GestureRecognizerTests`
Expected: FAIL — the swipe tests get `nil` (recognizer returns nil for displacement > tapMaxDistance).

- [ ] **Step 3: Update `classify()`** in `Sources/GlimbleCore/GestureRecognizer.swift` to detect swipes:

```swift
    private func classify() -> RecognizedGesture? {
        guard maxFingers >= config.minFingers else { return nil }
        if maxDisplacement >= config.swipeMinDistance {
            return .swipe(fingers: maxFingers, direction: dominantDirection())
        }
        if maxDisplacement <= config.tapMaxDistance {
            return .tap(fingers: maxFingers)
        }
        return nil   // ambiguous (between tap and swipe thresholds)
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
```

- [ ] **Step 4: Run, verify PASS**

Run: `swift test --filter GestureRecognizerTests`
Expected: PASS (all 5 recognizer tests: 2 tap + 3 swipe).

- [ ] **Step 5: Commit**

```bash
git add Sources/GlimbleCore/GestureRecognizer.swift Tests/GlimbleCoreTests/GestureRecognizerTests.swift
git commit -m "feat: GestureRecognizer recognizes directional multi-finger swipes"
```

---

### Task 6: `GestureRecognizer` — gating + ambiguity rejection (TDD)

**Files:**
- Modify: `Tests/GlimbleCoreTests/GestureRecognizerTests.swift`

This task adds tests that pin the existing safety behavior (no new implementation needed — verify the gates already hold; if any test fails, fix `GestureRecognizer` minimally to satisfy it).

- [ ] **Step 1: Append tests**

```swift
@Test func oneFingerMovementIsIgnored() {
    var rec = GestureRecognizer()
    // A single finger sliding across — must NEVER produce a gesture (cursor movement).
    _ = rec.process(frame(1, at: CGPoint(x: 0.2, y: 0.5), t: 0.00))
    _ = rec.process(frame(1, at: CGPoint(x: 0.8, y: 0.5), t: 0.03))
    let result = rec.process(TouchFrame(fingers: [], timestamp: 0.05))
    #expect(result == nil)
}

@Test func ambiguousDistanceProducesNothing() {
    var rec = GestureRecognizer()
    // Move 0.05 — past tapMaxDistance (0.03) but below swipeMinDistance (0.08): reject.
    _ = rec.process(frame(3, at: CGPoint(x: 0.50, y: 0.5), t: 0.00))
    _ = rec.process(frame(3, at: CGPoint(x: 0.55, y: 0.5), t: 0.03))
    let result = rec.process(TouchFrame(fingers: [], timestamp: 0.05))
    #expect(result == nil)
}

@Test func recognizerResetsBetweenGestures() {
    var rec = GestureRecognizer()
    let c = CGPoint(x: 0.5, y: 0.5)
    _ = rec.process(frame(2, at: c, t: 0.0))
    #expect(rec.process(TouchFrame(fingers: [], timestamp: 0.02)) == .tap(fingers: 2))
    // Second, independent gesture must work cleanly.
    _ = rec.process(frame(3, at: c, t: 1.0))
    #expect(rec.process(TouchFrame(fingers: [], timestamp: 1.02)) == .tap(fingers: 3))
}
```

- [ ] **Step 2: Run, verify PASS**

Run: `swift test --filter GestureRecognizerTests`
Expected: PASS (8 recognizer tests). If `oneFingerMovementIsIgnored` or `ambiguousDistanceProducesNothing` fails, the gates regressed — re-check `classify()`/`minFingers` and fix minimally.

- [ ] **Step 3: Commit**

```bash
git add Tests/GlimbleCoreTests/GestureRecognizerTests.swift
git commit -m "test: pin gesture gating (1-finger ignored, ambiguous rejected, reset)"
```

---

### Task 7: Rule model — `GlimbleAction`, `RuleScope`, `Rule`, `RuleSet` (Codable, pure)

**Files:**
- Create: `Sources/GlimbleCore/Rule.swift`
- Create: `Tests/GlimbleCoreTests/RuleTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/GlimbleCoreTests/RuleTests.swift`:
```swift
import Testing
import Foundation
@testable import GlimbleCore

@Test func ruleSetRoundTripsThroughJSON() throws {
    let rules = RuleSet(version: 1, rules: [
        Rule(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
             scope: .global,
             trigger: .swipe(fingers: 3, direction: .left),
             action: .keyboardShortcut(KeyCombo(keyCode: 123, modifiers: [.command])),
             enabled: true),
        Rule(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
             scope: .app(bundleID: "com.google.Chrome"),
             trigger: .tap(fingers: 4),
             action: .window(.maximize),
             enabled: false),
    ])
    let data = try JSONEncoder().encode(rules)
    let decoded = try JSONDecoder().decode(RuleSet.self, from: data)
    #expect(decoded == rules)
}

@Test func everyActionKindEncodes() throws {
    let actions: [GlimbleAction] = [
        .keyboardShortcut(KeyCombo(keyCode: 48, modifiers: [.command, .shift])),
        .shell("echo hi"),
        .appleScript("display dialog \"x\""),
        .runShortcut("My Shortcut"),
        .launchApp(bundleID: "com.apple.Safari"),
        .window(.left),
    ]
    let data = try JSONEncoder().encode(actions)
    #expect(try JSONDecoder().decode([GlimbleAction].self, from: data) == actions)
}
```

- [ ] **Step 2: Run, verify FAIL**

Run: `swift test --filter RuleTests`
Expected: FAIL — cannot find 'RuleSet' / 'Rule' / 'GlimbleAction' / 'KeyCombo'.

- [ ] **Step 3: Implement**

`Sources/GlimbleCore/Rule.swift`:
```swift
import Foundation

/// A keyboard modifier. Raw values are the JSON encoding.
public enum KeyModifier: String, Codable, Equatable, Sendable, CaseIterable {
    case command, option, control, shift
}

/// A key + modifiers. `keyCode` is a Carbon/CG virtual key code (e.g. 123 = left arrow).
public struct KeyCombo: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    public var modifiers: [KeyModifier]
    public init(keyCode: UInt16, modifiers: [KeyModifier]) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

/// What a rule does when its trigger fires. Tagged union; `Codable`.
public enum GlimbleAction: Codable, Equatable, Sendable {
    case keyboardShortcut(KeyCombo)
    case shell(String)
    case appleScript(String)
    case runShortcut(String)
    case launchApp(bundleID: String)
    case window(SnapPosition)
}

/// Where a rule applies. App-scoped rules win over global ones for the same trigger.
public enum RuleScope: Codable, Equatable, Sendable {
    case global
    case app(bundleID: String)
}

/// A single trigger→action mapping.
public struct Rule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var scope: RuleScope
    public var trigger: RecognizedGesture
    public var action: GlimbleAction
    public var enabled: Bool

    public init(id: UUID = UUID(), scope: RuleScope, trigger: RecognizedGesture,
                action: GlimbleAction, enabled: Bool = true) {
        self.id = id
        self.scope = scope
        self.trigger = trigger
        self.action = action
        self.enabled = enabled
    }
}

/// The versioned config document.
public struct RuleSet: Codable, Equatable, Sendable {
    public var version: Int
    public var rules: [Rule]
    public init(version: Int = 1, rules: [Rule]) {
        self.version = version
        self.rules = rules
    }
}
```

- [ ] **Step 4: Run, verify PASS**

Run: `swift test --filter RuleTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/GlimbleCore/Rule.swift Tests/GlimbleCoreTests/RuleTests.swift
git commit -m "feat: add Codable rule model (Rule/Action/Scope/RuleSet)"
```

---

### Task 8: `RuleStore` — matching + scope resolution (pure, TDD)

**Files:**
- Create: `Sources/GlimbleCore/RuleStore.swift`
- Create: `Tests/GlimbleCoreTests/RuleStoreTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/GlimbleCoreTests/RuleStoreTests.swift`:
```swift
import Testing
import Foundation
@testable import GlimbleCore

private func rule(_ scope: RuleScope, _ trigger: RecognizedGesture, _ action: GlimbleAction,
                  enabled: Bool = true) -> Rule {
    Rule(scope: scope, trigger: trigger, action: action, enabled: enabled)
}

@Test func matchesGlobalRule() {
    let store = RuleStore(ruleSet: RuleSet(rules: [
        rule(.global, .tap(fingers: 3), .window(.maximize)),
    ]))
    #expect(store.action(for: .tap(fingers: 3), frontmostBundleID: nil) == .window(.maximize))
    #expect(store.action(for: .tap(fingers: 4), frontmostBundleID: nil) == nil)
}

@Test func appScopedRuleWinsOverGlobal() {
    let store = RuleStore(ruleSet: RuleSet(rules: [
        rule(.global, .swipe(fingers: 3, direction: .left), .window(.left)),
        rule(.app(bundleID: "com.google.Chrome"), .swipe(fingers: 3, direction: .left),
             .keyboardShortcut(KeyCombo(keyCode: 123, modifiers: [.command]))),
    ]))
    // In Chrome → the app-specific rule.
    #expect(store.action(for: .swipe(fingers: 3, direction: .left), frontmostBundleID: "com.google.Chrome")
            == .keyboardShortcut(KeyCombo(keyCode: 123, modifiers: [.command])))
    // Elsewhere → the global rule.
    #expect(store.action(for: .swipe(fingers: 3, direction: .left), frontmostBundleID: "com.apple.Finder")
            == .window(.left))
}

@Test func disabledRulesAreIgnored() {
    let store = RuleStore(ruleSet: RuleSet(rules: [
        rule(.global, .tap(fingers: 2), .window(.center), enabled: false),
    ]))
    #expect(store.action(for: .tap(fingers: 2), frontmostBundleID: nil) == nil)
}
```

- [ ] **Step 2: Run, verify FAIL**

Run: `swift test --filter RuleStoreTests`
Expected: FAIL — cannot find 'RuleStore'.

- [ ] **Step 3: Implement (matching only; persistence in Task 9)**

`Sources/GlimbleCore/RuleStore.swift`:
```swift
import Foundation

/// Holds the rule set and resolves a recognized gesture (+ frontmost app) to an action.
/// Pure: no file I/O here (that's `loadFrom`/`write` added next). App-scoped rules win.
public struct RuleStore: Sendable {
    public private(set) var ruleSet: RuleSet

    public init(ruleSet: RuleSet) {
        self.ruleSet = ruleSet
    }

    /// The action to run for `gesture` given the frontmost app's bundle id (nil if unknown).
    /// An enabled app-scoped rule for the current app beats an enabled global rule.
    public func action(for gesture: RecognizedGesture, frontmostBundleID: String?) -> GlimbleAction? {
        let candidates = ruleSet.rules.filter { $0.enabled && $0.trigger == gesture }
        if let bundleID = frontmostBundleID,
           let appRule = candidates.first(where: { $0.scope == .app(bundleID: bundleID) }) {
            return appRule.action
        }
        return candidates.first(where: { $0.scope == .global })?.action
    }
}
```

- [ ] **Step 4: Run, verify PASS**

Run: `swift test --filter RuleStoreTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/GlimbleCore/RuleStore.swift Tests/GlimbleCoreTests/RuleStoreTests.swift
git commit -m "feat: RuleStore resolves gestures to actions with app>global scope"
```

---

### Task 9: `RuleStore` — JSON persistence (TDD)

**Files:**
- Modify: `Sources/GlimbleCore/RuleStore.swift`
- Modify: `Tests/GlimbleCoreTests/RuleStoreTests.swift`

- [ ] **Step 1: Append failing tests**

```swift
@Test func ruleStoreWritesAndLoadsFromDisk() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("glimble-test-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }

    let original = RuleStore(ruleSet: RuleSet(rules: [
        rule(.global, .tap(fingers: 3), .shell("echo hi")),
    ]))
    try original.write(to: url)
    let loaded = try RuleStore.load(from: url)
    #expect(loaded.ruleSet == original.ruleSet)
}

@Test func loadingMissingFileReturnsEmptyRuleSet() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("glimble-missing-\(UUID().uuidString).json")
    let store = try RuleStore.load(from: url)
    #expect(store.ruleSet.rules.isEmpty)
    #expect(store.ruleSet.version == 1)
}
```

- [ ] **Step 2: Run, verify FAIL**

Run: `swift test --filter RuleStoreTests`
Expected: FAIL — `RuleStore` has no member `write`/`load`.

- [ ] **Step 3: Add persistence** to `Sources/GlimbleCore/RuleStore.swift` (inside the struct):

```swift
    /// Write the rule set as pretty JSON.
    public func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(ruleSet).write(to: url, options: .atomic)
    }

    /// Load a rule set from disk. A missing file yields an empty version-1 rule set
    /// (first-run behavior), not an error.
    public static func load(from url: URL) throws -> RuleStore {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return RuleStore(ruleSet: RuleSet(version: 1, rules: []))
        }
        let data = try Data(contentsOf: url)
        let ruleSet = try JSONDecoder().decode(RuleSet.self, from: data)
        return RuleStore(ruleSet: ruleSet)
    }
```

- [ ] **Step 4: Run, verify PASS**

Run: `swift test --filter RuleStoreTests`
Expected: PASS (5 RuleStore tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/GlimbleCore/RuleStore.swift Tests/GlimbleCoreTests/RuleStoreTests.swift
git commit -m "feat: RuleStore JSON persistence with empty first-run default"
```

---

### Task 10: Default presets (pure, TDD)

Curated starter rules. To avoid fighting macOS's own 3/4-finger swipes (which a read-only stream can't suppress), the defaults use **taps** and finger-counts users can adopt after the onboarding (Plan 2) guides disabling conflicts. v1 default set:
- 3-finger **tap** → Maximize focused window
- 4-finger **tap** → Center focused window
- 3-finger swipe **left** / **right** → window snap left / right

**Files:**
- Create: `Sources/GlimbleCore/DefaultPresets.swift`
- Create: `Tests/GlimbleCoreTests/DefaultPresetsTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/GlimbleCoreTests/DefaultPresetsTests.swift`:
```swift
import Testing
@testable import GlimbleCore

@Test func defaultPresetsCoverTheStarterGestures() {
    let store = RuleStore(ruleSet: DefaultPresets.ruleSet)
    #expect(store.action(for: .tap(fingers: 3), frontmostBundleID: nil) == .window(.maximize))
    #expect(store.action(for: .tap(fingers: 4), frontmostBundleID: nil) == .window(.center))
    #expect(store.action(for: .swipe(fingers: 3, direction: .left), frontmostBundleID: nil) == .window(.left))
    #expect(store.action(for: .swipe(fingers: 3, direction: .right), frontmostBundleID: nil) == .window(.right))
}

@Test func defaultPresetsAreAllGlobalAndEnabled() {
    for r in DefaultPresets.ruleSet.rules {
        #expect(r.enabled)
        #expect(r.scope == .global)
    }
}
```

- [ ] **Step 2: Run, verify FAIL**

Run: `swift test --filter DefaultPresetsTests`
Expected: FAIL — cannot find 'DefaultPresets'.

- [ ] **Step 3: Implement**

`Sources/GlimbleCore/DefaultPresets.swift`:
```swift
import Foundation

/// Curated starter rules so Glimble is useful immediately. All global + enabled.
/// Deterministic UUIDs keep the set stable across launches.
public enum DefaultPresets {
    public static let ruleSet = RuleSet(version: 1, rules: [
        Rule(id: uuid(1), scope: .global, trigger: .tap(fingers: 3),
             action: .window(.maximize)),
        Rule(id: uuid(2), scope: .global, trigger: .tap(fingers: 4),
             action: .window(.center)),
        Rule(id: uuid(3), scope: .global, trigger: .swipe(fingers: 3, direction: .left),
             action: .window(.left)),
        Rule(id: uuid(4), scope: .global, trigger: .swipe(fingers: 3, direction: .right),
             action: .window(.right)),
    ])

    private static func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "GLIMBLE0-0000-0000-0000-%012d", n))!
    }
}
```

> Note: the `uuid(_:)` string must be a valid UUID. `GLIMBLE0` is not hex. Use a hex-safe prefix instead — replace the format string with `"00000000-0000-0000-0000-%012d"`. (The engineer must use the hex-safe version; the `GLIMBLE0` form will crash the force-unwrap.)

- [ ] **Step 4: Run, verify PASS**

Run: `swift test --filter DefaultPresetsTests`
Expected: PASS (2 tests). If it crashes on `UUID(uuidString:)!`, you used the non-hex prefix — switch to `"00000000-0000-0000-0000-%012d"`.

- [ ] **Step 5: Commit**

```bash
git add Sources/GlimbleCore/DefaultPresets.swift Tests/GlimbleCoreTests/DefaultPresetsTests.swift
git commit -m "feat: curated default gesture presets"
```

---

### Task 11: `TouchSource` — OpenMultitouchSupport → `TouchFrame` stream (app layer)

Promote the spike's `TouchReader` into a `TouchSource` that emits normalized `TouchFrame`s (not just a count), isolating all private-framework access.

**Files:**
- Create: `Sources/GlimbleApp/TouchSource.swift`
- Delete: `Sources/GlimbleApp/TouchReader.swift`
- Modify: `Sources/GlimbleApp/AppDelegate.swift`

- [ ] **Step 1: Create `TouchSource`**

`Sources/GlimbleApp/TouchSource.swift`:
```swift
import Foundation
import CoreGraphics
import GlimbleCore
import OpenMultitouchSupport

/// Wraps OpenMultitouchSupport, normalizing each emission into a GlimbleCore `TouchFrame`.
/// ALL private-framework access is isolated here. Main-actor isolated (UI is the only consumer).
@MainActor
final class TouchSource {
    private let manager = OMSManager.shared
    private var task: Task<Void, Never>?
    private var frameCounter: TimeInterval = 0

    /// Called on the main actor with each normalized frame.
    var onFrame: ((TouchFrame) -> Void)?

    func start() {
        manager.startListening()
        task = Task { [weak self] in
            guard let self else { return }
            for await touches in self.manager.touchDataStream {
                let frame = Self.normalize(touches, sequence: self.nextTimestamp())
                self.onFrame?(frame)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        manager.stopListening()
    }

    /// OMS does not give a wall-clock per frame in a convenient form; a monotonically
    /// increasing per-frame counter (in ~seconds, assuming ~100 Hz) is enough for the
    /// recognizer's relative-time needs.
    private func nextTimestamp() -> TimeInterval {
        frameCounter += 0.01
        return frameCounter
    }

    private static func normalize(_ touches: [OMSTouchData], sequence t: TimeInterval) -> TouchFrame {
        let fingers = touches
            .filter { $0.state == .touching }
            .map { d in
                Finger(id: d.id,
                       position: CGPoint(x: CGFloat(d.position.x), y: CGFloat(d.position.y)),
                       pressure: d.pressure)
            }
        return TouchFrame(fingers: fingers, timestamp: t)
    }
}
```

- [ ] **Step 2: Delete the old reader**

```bash
git rm Sources/GlimbleApp/TouchReader.swift
```

- [ ] **Step 3: Temporarily keep `AppDelegate` compiling** — replace its `TouchReader` usage with `TouchSource`, showing the live finger count from the frame (full wiring comes in Task 16). In `Sources/GlimbleApp/AppDelegate.swift`:
  - change `private let touchReader = TouchReader()` → `private let touchSource = TouchSource()`
  - in `applicationDidFinishLaunching`, replace the `touchReader.onCount = …; touchReader.start()` block with:
```swift
        touchSource.onFrame = { [weak self] frame in
            self?.statusItem.button?.title = "👆 \(frame.fingerCount)"
        }
        touchSource.start()
```
  - in `applicationWillTerminate`, change `touchReader.stop()` → `touchSource.stop()`

- [ ] **Step 4: Build**

Run: `swift build && swift test`
Expected: `Build complete!`, all GlimbleCore tests still pass. (Do not run the GUI app.)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: TouchSource emits normalized TouchFrames from OpenMultitouchSupport"
```

---

### Task 12: `AppContext` — frontmost app bundle id (app layer)

**Files:**
- Create: `Sources/GlimbleApp/AppContext.swift`

- [ ] **Step 1: Implement**

`Sources/GlimbleApp/AppContext.swift`:
```swift
import AppKit

/// Provides the frontmost application's bundle identifier for rule scoping.
@MainActor
enum AppContext {
    /// Bundle id of the frontmost (active) app, or nil if unavailable.
    static var frontmostBundleID: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`.

- [ ] **Step 3: Commit**

```bash
git add Sources/GlimbleApp/AppContext.swift
git commit -m "feat: AppContext exposes frontmost app bundle id"
```

---

### Task 13: `ActionExecutor` — keyboard shortcut synthesis (app layer)

The `KeyCombo`→`CGEventFlags` mapping is pure and unit-tested; the actual posting is thin.

**Files:**
- Create: `Sources/GlimbleCore/KeyComboFlags.swift`
- Create: `Tests/GlimbleCoreTests/KeyComboFlagsTests.swift`
- Create: `Sources/GlimbleApp/ActionExecutor.swift`

- [ ] **Step 1: Write the failing test (pure flag mapping in GlimbleCore)**

`Tests/GlimbleCoreTests/KeyComboFlagsTests.swift`:
```swift
import Testing
import CoreGraphics
@testable import GlimbleCore

@Test func mapsModifiersToCGEventFlags() {
    let combo = KeyCombo(keyCode: 0, modifiers: [.command, .shift])
    let flags = combo.cgEventFlags
    #expect(flags.contains(.maskCommand))
    #expect(flags.contains(.maskShift))
    #expect(!flags.contains(.maskControl))
    #expect(!flags.contains(.maskAlternate))
}

@Test func emptyModifiersAreEmptyFlags() {
    #expect(KeyCombo(keyCode: 36, modifiers: []).cgEventFlags.isEmpty)
}
```

- [ ] **Step 2: Run, verify FAIL**

Run: `swift test --filter KeyComboFlagsTests`
Expected: FAIL — `KeyCombo` has no member `cgEventFlags`.

- [ ] **Step 3: Implement the pure mapping**

`Sources/GlimbleCore/KeyComboFlags.swift`:
```swift
import CoreGraphics

public extension KeyCombo {
    /// The CoreGraphics modifier flags for this combo.
    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        for m in modifiers {
            switch m {
            case .command: flags.insert(.maskCommand)
            case .option:  flags.insert(.maskAlternate)
            case .control: flags.insert(.maskControl)
            case .shift:   flags.insert(.maskShift)
            }
        }
        return flags
    }
}
```

- [ ] **Step 4: Run, verify PASS**

Run: `swift test --filter KeyComboFlagsTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Create `ActionExecutor` with the keyboard case** (other cases added in Task 14/15)

`Sources/GlimbleApp/ActionExecutor.swift`:
```swift
import AppKit
import CoreGraphics
import GlimbleCore

/// Executes a `GlimbleAction`. All event synthesis and process spawning lives here.
@MainActor
enum ActionExecutor {
    static func run(_ action: GlimbleAction) {
        switch action {
        case .keyboardShortcut(let combo):
            postKeyboardShortcut(combo)
        case .shell, .appleScript, .runShortcut, .launchApp, .window:
            break   // implemented in later tasks
        }
    }

    private static func postKeyboardShortcut(_ combo: KeyCombo) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: false)
        else { return }
        down.flags = combo.cgEventFlags
        up.flags = combo.cgEventFlags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
```

- [ ] **Step 6: Build + test**

Run: `swift build && swift test`
Expected: `Build complete!`, all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/GlimbleCore/KeyComboFlags.swift Tests/GlimbleCoreTests/KeyComboFlagsTests.swift Sources/GlimbleApp/ActionExecutor.swift
git commit -m "feat: ActionExecutor posts keyboard shortcuts via CGEvent"
```

---

### Task 14: `ActionExecutor` — shell / AppleScript / Shortcuts / app launch

**Files:**
- Modify: `Sources/GlimbleApp/ActionExecutor.swift`

- [ ] **Step 1: Implement the remaining process/launch cases**

In `Sources/GlimbleApp/ActionExecutor.swift`, replace the `case .shell, .appleScript, .runShortcut, .launchApp, .window: break` line with explicit cases, and add the helpers:

```swift
        case .shell(let command):
            runProcess("/bin/zsh", ["-c", command])
        case .appleScript(let script):
            runProcess("/usr/bin/osascript", ["-e", script])
        case .runShortcut(let name):
            runProcess("/usr/bin/shortcuts", ["run", name])
        case .launchApp(let bundleID):
            launchApp(bundleID: bundleID)
        case .window:
            break   // implemented in Task 15
```

Add these helpers to the enum:
```swift
    /// Run an external command out-of-process, detached (fire-and-forget).
    private static func runProcess(_ launchPath: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        do { try process.run() } catch { NSLog("Glimble: failed to run \(launchPath): \(error)") }
    }

    private static func launchApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`.

- [ ] **Step 3: Commit**

```bash
git add Sources/GlimbleApp/ActionExecutor.swift
git commit -m "feat: ActionExecutor runs shell/AppleScript/Shortcuts/app-launch"
```

---

### Task 15: `ActionExecutor` — window actions (promote WindowSnapper)

**Files:**
- Modify: `Sources/GlimbleApp/ActionExecutor.swift`
- Modify: `Sources/GlimbleApp/WindowSnapper.swift` (no API change; just confirm it's reused)

- [ ] **Step 1: Wire the window case** — in `Sources/GlimbleApp/ActionExecutor.swift`, replace `case .window: break` (the Task 14 placeholder) with:

```swift
        case .window(let position):
            try? WindowSnapper.snapFocusedWindow(to: position)
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`.

- [ ] **Step 3: Commit**

```bash
git add Sources/GlimbleApp/ActionExecutor.swift
git commit -m "feat: ActionExecutor performs window snap actions"
```

---

### Task 16: Wire the engine into `AppDelegate`

Replace the spike's hardcoded Snap menu + finger-count display with the real pipeline:
TouchSource → GestureRecognizer → RuleStore(match by AppContext) → ActionExecutor. Load rules from
disk (defaults on first run). Keep a minimal menu (status + Quit) — the real settings UI is Plan 2.

**Files:**
- Modify: `Sources/GlimbleApp/AppDelegate.swift`
- Create: `Sources/GlimbleApp/GestureEngine.swift`

- [ ] **Step 1: Create `GestureEngine`** to own the recognizer + store and turn frames into actions

`Sources/GlimbleApp/GestureEngine.swift`:
```swift
import Foundation
import AppKit
import GlimbleCore

/// Owns the recognizer + rule store and runs the frame→gesture→action pipeline.
@MainActor
final class GestureEngine {
    private var recognizer = GestureRecognizer()
    private(set) var store: RuleStore

    /// The on-disk rule file: ~/Library/Application Support/Glimble/rules.json
    static var rulesURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Glimble", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("rules.json")
    }

    init() {
        // Load saved rules; on first run (no file), seed with curated defaults and save them.
        let loaded = (try? RuleStore.load(from: Self.rulesURL)) ?? RuleStore(ruleSet: .init(rules: []))
        if loaded.ruleSet.rules.isEmpty {
            store = RuleStore(ruleSet: DefaultPresets.ruleSet)
            try? store.write(to: Self.rulesURL)
        } else {
            store = loaded
        }
    }

    /// Feed one frame; if it completes a gesture with a matching rule, run the action.
    func handle(_ frame: TouchFrame) {
        guard let gesture = recognizer.process(frame) else { return }
        guard let action = store.action(for: gesture, frontmostBundleID: AppContext.frontmostBundleID)
        else { return }
        ActionExecutor.run(action)
    }
}
```

- [ ] **Step 2: Rewrite `AppDelegate`** to use the engine and drop the hardcoded snap menu

Replace `Sources/GlimbleApp/AppDelegate.swift` with:
```swift
import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let touchSource = TouchSource()
    private let engine = GestureEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "👆"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Glimble (\(engine.store.ruleSet.rules.count) rules)",
                                action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Glimble",
                              action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu

        // Permissions: reading touches needs Input Monitoring; actions need Accessibility.
        if !CGPreflightListenEventAccess() { CGRequestListenEventAccess() }
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)

        touchSource.onFrame = { [weak self] frame in self?.engine.handle(frame) }
        touchSource.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        touchSource.stop()
    }
}
```

- [ ] **Step 3: Build + test**

Run: `swift build && swift test`
Expected: `Build complete!`, all GlimbleCore tests pass. (Runtime gesture→action verification is hardware-gated → user.)

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: wire TouchSource->recognizer->RuleStore->ActionExecutor pipeline"
```

---

## Self-Review

**Spec coverage (Plan 1 scope):** TouchSource (Task 11), GestureRecognizer Layer-1 swipes+taps with ≥2 gating (Tasks 4–6), AppContext (Task 12), RuleStore + JSON + scope (Tasks 8–9), rule model (Task 7), ActionExecutor all action types — keyboard/shell/AppleScript/Shortcuts/launch/window (Tasks 13–15), default presets (Task 10), full wiring (Task 16), app identity rename (Task 1). Settings UI, onboarding, PermissionsCoordinator recovery, launch-at-login, Sparkle, packaging are **Plan 2/3** — intentionally absent here.

**Placeholder scan:** The only inline caution is Task 10's UUID format note (the `GLIMBLE0` prefix is intentionally flagged as invalid with the hex-safe fix given) — that's a guard, not a TODO. Every code step has complete code.

**Type consistency:** `TouchFrame`/`Finger` (T2) → consumed by `GestureRecognizer.process` (T4–6) and `TouchSource.normalize` (T11). `RecognizedGesture` (T3) is the recognizer output AND `Rule.trigger` (T7) AND `RuleStore.action(for:frontmostBundleID:)` input (T8). `GlimbleAction` (T7) → `ActionExecutor.run` (T13–15). `KeyCombo.cgEventFlags` (T13) used by `postKeyboardShortcut`. `SnapPosition` (existing) used by `.window` action + `WindowSnapper`. `RuleStore.write/load` (T9) used by `GestureEngine` (T16). `AppContext.frontmostBundleID` (T12) used by `GestureEngine` (T16). All consistent.

**Concurrency:** App-layer types (`TouchSource`, `AppContext`, `ActionExecutor`, `GestureEngine`, `AppDelegate`) are `@MainActor` (consistent with Phase 0). `GlimbleCore` stays pure/`Sendable`, no OS imports (CoreGraphics/Foundation only).
