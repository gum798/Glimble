# Glimble Phase 0 — Risk-Burndown Spike Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a signed, notarized macOS menu-bar spike that proves Glimble's three load-bearing technical bets — (1) raw multitouch capture via the private framework works, (2) such an app passes notarization + Gatekeeper, (3) public-AX window snapping works including the Chrome/Electron workaround — before committing to the full v1 architecture.

**Architecture:** A single SwiftPM package at the repo root with three targets: a pure, OS-import-free `GlimbleCore` library (window geometry math, TDD-tested via Swift Testing); a `GlimbleSpike` AppKit executable (menu-bar agent, `.accessory` activation policy / `LSUIElement`) that links `OpenMultitouchSupport` and drives live touch capture + AX window snapping; and a `GlimbleCoreTests` test target. CLI build scripts assemble the executable into a `.app` bundle, sign it with Developer ID + Hardened Runtime + the `disable-library-validation` entitlement, notarize via `notarytool`, and staple.

**Tech Stack:** Swift 6.x (swift-tools 6.0+), Swift Testing, AppKit, ApplicationServices (Accessibility/AXUIElement), CoreGraphics, `Kyome22/OpenMultitouchSupport` (SwiftPM, MIT), `xcrun notarytool`/`stapler`/`codesign`.

---

## Why a SwiftPM CLI spike (not an Xcode project)

The spec recommends an Xcode `.app` target for **Phase 1** because of Sparkle's multi-component XPC signing. Phase 0 has no Sparkle, so a pure-SwiftPM executable assembled into a bundle by a shell script is the leanest path: every step is a verifiable CLI command (no GUI clicks to script), and the notarization bet is identical — `notarytool` does not care whether the bundle came from Xcode or `swift build`, only that it is correctly signed with Hardened Runtime. Phase 1 migrates to Xcode.

## Prerequisites (must be true before Task 4 onward)

These are external and cannot be created by code. Confirm each before the signing/notarization/hardware tasks:

- macOS 15+ dev machine with a Swift 6 toolchain (`swift --version` ≥ 6.0).
- **Apple Developer Program** membership.
- A **Developer ID Application** signing identity installed in the login keychain. Verify: `security find-identity -v -p codesigning` lists a `Developer ID Application: … (TEAMID)` entry. Record that exact string — it is referenced as `$IDENTITY`.
- A stored notarytool credential profile (created once): `xcrun notarytool store-credentials glimble-notary --apple-id <id> --team-id <TEAMID> --password <app-specific-pw>` (or `--key`/`--key-id`/`--issuer` for an App Store Connect API key — preferred). The profile name is referenced as `glimble-notary`.
- For the capture matrix (Task 5/Task 11): access to **macOS 15 and macOS 26**, on **Intel and Apple Silicon** (physical MacBooks with built-in trackpads — VMs have no trackpad). A clean macOS 26 machine/VM for the Gatekeeper test (Task 10).

**Commit hygiene:** every commit message in this plan should end with the repo's `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` trailer (omitted from the example commands below for readability). Build artifacts (`.build/`, `*.app`, `*.zip`) must be git-ignored (Task 1).

**Tasks 1–3 are strict TDD** (pure logic). **Tasks 4–11 are verification tasks** — notarization passing and touch frames arriving on real hardware cannot be expressed as a failing-then-passing unit test, so those tasks use exact commands + expected output + a recorded result instead of a red/green loop. This is intentional, not a gap.

---

### Task 1: Package scaffold + SnapPosition type + gitignore

**Files:**
- Create: `Package.swift`
- Create: `Sources/GlimbleCore/SnapPosition.swift`
- Create: `Sources/GlimbleCore/Placeholder.swift` (temporary, removed in Task 2)
- Create: `Tests/GlimbleCoreTests/SmokeTest.swift`
- Create: `.gitignore`

- [ ] **Step 1: Create `.gitignore`**

```gitignore
.build/
*.app
*.zip
.DS_Store
*.xcodeproj
DerivedData/
```

- [ ] **Step 2: Create `Package.swift`**

`GlimbleCore` is pure (no platform-restricted APIs) so it can be tested on any host; the package platform floor is macOS 15 because the `GlimbleSpike` executable (added in Task 4) needs it.

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Glimble",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "GlimbleCore", targets: ["GlimbleCore"]),
    ],
    targets: [
        .target(name: "GlimbleCore"),
        .testTarget(name: "GlimbleCoreTests", dependencies: ["GlimbleCore"]),
    ]
)
```

- [ ] **Step 3: Create `Sources/GlimbleCore/SnapPosition.swift`**

```swift
/// A target region for snapping the focused window, expressed independently of any
/// coordinate system. Geometry is resolved against a visible frame in `WindowGeometry`.
public enum SnapPosition: String, CaseIterable, Sendable {
    case left, right, top, bottom
    case topLeft, topRight, bottomLeft, bottomRight
    case maximize, center
}
```

- [ ] **Step 4: Create `Sources/GlimbleCore/Placeholder.swift`** (so the target compiles before Task 2 adds real code)

```swift
// Temporary: removed in Task 2 once WindowGeometry exists.
enum _GlimbleCorePlaceholder {}
```

- [ ] **Step 5: Create `Tests/GlimbleCoreTests/SmokeTest.swift`**

```swift
import Testing
@testable import GlimbleCore

@Test func snapPositionHasAllCases() {
    #expect(SnapPosition.allCases.count == 10)
}
```

- [ ] **Step 6: Build and run the smoke test**

Run: `swift test`
Expected: builds, 1 test passes.

- [ ] **Step 7: Commit**

```bash
git add .gitignore Package.swift Sources Tests
git commit -m "feat: scaffold Glimble SwiftPM package with SnapPosition"
```

---

### Task 2: Window geometry — `snapRect` (TDD)

Computes the target rectangle for a snap position, in the **same coordinate space as the input visible frame** (AppKit, bottom-left origin). No flipping yet — that is Task 3.

**Files:**
- Create: `Sources/GlimbleCore/WindowGeometry.swift`
- Delete: `Sources/GlimbleCore/Placeholder.swift`
- Create: `Tests/GlimbleCoreTests/WindowGeometryTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/GlimbleCoreTests/WindowGeometryTests.swift`:

```swift
import Testing
import CoreGraphics
@testable import GlimbleCore

// Single 1920x1080 display, menu bar 25px tall at top, no Dock:
// AppKit visibleFrame = origin (0,0), size 1920 x 1055.
private let vf = CGRect(x: 0, y: 0, width: 1920, height: 1055)

@Test func maximizeFillsVisibleFrame() {
    #expect(WindowGeometry.snapRect(.maximize, in: vf) == vf)
}

@Test func leftHalf() {
    #expect(WindowGeometry.snapRect(.left, in: vf) == CGRect(x: 0, y: 0, width: 960, height: 1055))
}

@Test func rightHalf() {
    #expect(WindowGeometry.snapRect(.right, in: vf) == CGRect(x: 960, y: 0, width: 960, height: 1055))
}

@Test func topHalfIsHigherYInAppKit() {
    // AppKit bottom-left origin: the top half has the larger y.
    #expect(WindowGeometry.snapRect(.top, in: vf) == CGRect(x: 0, y: 527.5, width: 1920, height: 527.5))
}

@Test func bottomHalf() {
    #expect(WindowGeometry.snapRect(.bottom, in: vf) == CGRect(x: 0, y: 0, width: 1920, height: 527.5))
}

@Test func topLeftQuarter() {
    #expect(WindowGeometry.snapRect(.topLeft, in: vf) == CGRect(x: 0, y: 527.5, width: 960, height: 527.5))
}

@Test func bottomRightQuarter() {
    #expect(WindowGeometry.snapRect(.bottomRight, in: vf) == CGRect(x: 960, y: 0, width: 960, height: 527.5))
}

@Test func centerIsSixtyPercentCentered() {
    let r = WindowGeometry.snapRect(.center, in: vf)
    #expect(abs(r.width - 1152) < 0.001)   // 1920 * 0.6
    #expect(abs(r.height - 633) < 0.001)   // 1055 * 0.6
    #expect(abs(r.midX - vf.midX) < 0.001)
    #expect(abs(r.midY - vf.midY) < 0.001)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter WindowGeometryTests`
Expected: FAIL — `cannot find 'WindowGeometry' in scope`.

- [ ] **Step 3: Delete the placeholder and write the implementation**

Delete `Sources/GlimbleCore/Placeholder.swift`, then create `Sources/GlimbleCore/WindowGeometry.swift`:

```swift
import CoreGraphics

/// Pure window-geometry math. No AppKit / no OS imports → fully unit-testable.
public enum WindowGeometry {

    /// Target rect for `position` within `vf`, in the SAME coordinate space as `vf`
    /// (AppKit visible frame: bottom-left origin, y grows upward).
    public static func snapRect(_ position: SnapPosition, in vf: CGRect) -> CGRect {
        let halfW = vf.width / 2
        let halfH = vf.height / 2
        switch position {
        case .maximize:
            return vf
        case .left:
            return CGRect(x: vf.minX, y: vf.minY, width: halfW, height: vf.height)
        case .right:
            return CGRect(x: vf.minX + halfW, y: vf.minY, width: halfW, height: vf.height)
        case .top:
            return CGRect(x: vf.minX, y: vf.minY + halfH, width: vf.width, height: halfH)
        case .bottom:
            return CGRect(x: vf.minX, y: vf.minY, width: vf.width, height: halfH)
        case .topLeft:
            return CGRect(x: vf.minX, y: vf.minY + halfH, width: halfW, height: halfH)
        case .topRight:
            return CGRect(x: vf.minX + halfW, y: vf.minY + halfH, width: halfW, height: halfH)
        case .bottomLeft:
            return CGRect(x: vf.minX, y: vf.minY, width: halfW, height: halfH)
        case .bottomRight:
            return CGRect(x: vf.minX + halfW, y: vf.minY, width: halfW, height: halfH)
        case .center:
            let w = vf.width * 0.6
            let h = vf.height * 0.6
            return CGRect(x: vf.midX - w / 2, y: vf.midY - h / 2, width: w, height: h)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter WindowGeometryTests`
Expected: PASS — all 8 tests green.

- [ ] **Step 5: Commit**

```bash
git add Sources/GlimbleCore Tests/GlimbleCoreTests/WindowGeometryTests.swift
git commit -m "feat: add WindowGeometry.snapRect with tests"
```

---

### Task 3: Window geometry — AX coordinate flip (TDD)

Converts an AppKit rect (bottom-left origin) to the **top-left-origin global Quartz point** that `kAXPositionAttribute` expects. This is the spec's #1 multi-display bug; it gets its own tested function.

**Files:**
- Modify: `Sources/GlimbleCore/WindowGeometry.swift`
- Modify: `Tests/GlimbleCoreTests/WindowGeometryTests.swift`

- [ ] **Step 1: Add failing tests**

Append to `Tests/GlimbleCoreTests/WindowGeometryTests.swift`:

```swift
@Test func axFlipForLeftHalfSitsUnderMenuBar() {
    // Left-half AppKit rect on the primary display, primary is 1080 tall.
    let appKit = CGRect(x: 0, y: 0, width: 960, height: 1055)
    let origin = WindowGeometry.axOrigin(forAppKitRect: appKit, primaryHeight: 1080)
    // Top of window is 25px down (the menu-bar height): 1080 - 0 - 1055 = 25.
    #expect(origin == CGPoint(x: 0, y: 25))
}

@Test func axFlipGoesNegativeForDisplayAbovePrimary() {
    // A display stacked directly above the primary: AppKit origin.y = 1080.
    let appKit = CGRect(x: 0, y: 1080, width: 1920, height: 1080)
    let origin = WindowGeometry.axOrigin(forAppKitRect: appKit, primaryHeight: 1080)
    #expect(origin == CGPoint(x: 0, y: -1080))
}

@Test func axFlipPreservesX() {
    let appKit = CGRect(x: 960, y: 0, width: 960, height: 1055)
    let origin = WindowGeometry.axOrigin(forAppKitRect: appKit, primaryHeight: 1080)
    #expect(origin == CGPoint(x: 960, y: 25))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter WindowGeometryTests`
Expected: FAIL — `type 'WindowGeometry' has no member 'axOrigin'`.

- [ ] **Step 3: Add the implementation**

Add to the `WindowGeometry` enum in `Sources/GlimbleCore/WindowGeometry.swift`:

```swift
    /// Convert an AppKit rect (bottom-left origin) to the top-left-origin global
    /// Quartz point used by `kAXPositionAttribute`.
    /// `primaryHeight` is the height of the display whose AppKit frame origin is (0,0).
    /// Y is negative for displays stacked above the primary — that is correct.
    public static func axOrigin(forAppKitRect rect: CGRect, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: rect.origin.x, y: primaryHeight - rect.origin.y - rect.size.height)
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS — all tests (smoke + geometry + flip) green.

- [ ] **Step 5: Commit**

```bash
git add Sources/GlimbleCore/WindowGeometry.swift Tests/GlimbleCoreTests/WindowGeometryTests.swift
git commit -m "feat: add AX coordinate-flip to WindowGeometry with multi-display tests"
```

---

### Task 4: Add OpenMultitouchSupport, verify its facts, scaffold the menu-bar executable

Verification task (Phase 0 item #3 + the executable shell). Confirms the dependency's exact version/license/toolchain/API **before** any code depends on its symbols.

**Files:**
- Modify: `Package.swift`
- Create: `Sources/GlimbleSpike/main.swift`
- Create: `Sources/GlimbleSpike/AppDelegate.swift`
- Create: `Sources/GlimbleSpike/Info.plist`
- Create: `docs/superpowers/notes/openmultitouchsupport.md`

- [ ] **Step 1: Discover and record the exact OpenMultitouchSupport facts**

Run: `git ls-remote --tags https://github.com/Kyome22/OpenMultitouchSupport.git`
Pick the highest semver tag from the output — call it `X.Y.Z`. Then inspect its package manifest and license:

Run: `curl -s https://raw.githubusercontent.com/Kyome22/OpenMultitouchSupport/X.Y.Z/Package.swift`
Run: `curl -s https://raw.githubusercontent.com/Kyome22/OpenMultitouchSupport/X.Y.Z/LICENSE | head -3`

Create `docs/superpowers/notes/openmultitouchsupport.md` and record, from what you actually saw:
- exact tag `X.Y.Z` being pinned
- license (expected: MIT — fail the task and stop if it is GPL)
- `swift-tools-version` and minimum macOS in its `Package.swift`
- **whether the touch target is a normal source target or a `binaryTarget` (XCFramework)** — this determines whether Task 7 must embed + sign a dylib/framework
- the public symbols you will call, verbatim from its sources: the manager accessor (e.g. `OMSManager.shared`), `startListening`/`stopListening`, the stream property name and **element type** (single `OMSTouchData` vs `[OMSTouchData]`), and the `state` enum case used for an active touch (expected `.touching`)

- [ ] **Step 2: Add the dependency to `Package.swift`**

Replace `X.Y.Z` with the tag recorded in Step 1. Add the `GlimbleSpike` executable target:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Glimble",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "GlimbleCore", targets: ["GlimbleCore"]),
        .executable(name: "GlimbleSpike", targets: ["GlimbleSpike"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Kyome22/OpenMultitouchSupport.git", exact: "X.Y.Z"),
    ],
    targets: [
        .target(name: "GlimbleCore"),
        .executableTarget(
            name: "GlimbleSpike",
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

> Note: if Step 1 found the product name is not `OpenMultitouchSupport`, use the exact product name from its `Package.swift`.

- [ ] **Step 3: Create the bundle `Info.plist`**

`Sources/GlimbleSpike/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>          <string>com.glimble.spike</string>
    <key>CFBundleName</key>                <string>Glimble Spike</string>
    <key>CFBundleExecutable</key>          <string>GlimbleSpike</string>
    <key>CFBundlePackageType</key>         <string>APPL</string>
    <key>CFBundleShortVersionString</key>  <string>0.0.1</string>
    <key>CFBundleVersion</key>             <string>1</string>
    <key>LSUIElement</key>                 <true/>
    <key>LSMinimumSystemVersion</key>      <string>15.0</string>
    <key>NSPrincipalClass</key>            <string>NSApplication</string>
</dict>
</plist>
```

- [ ] **Step 4: Create the AppKit entry point**

`Sources/GlimbleSpike/main.swift`:

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // menu-bar agent, no Dock icon
app.run()
```

- [ ] **Step 5: Create a minimal `AppDelegate` (status item only, no capture yet)**

`Sources/GlimbleSpike/AppDelegate.swift`:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "👆 –"

        let menu = NSMenu()
        let quit = NSMenuItem(title: "Quit Glimble Spike",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu
    }
}
```

- [ ] **Step 6: Build and run; confirm the menu-bar item appears**

Run: `swift build` then `swift run GlimbleSpike`
Expected: no Dock icon; a `👆 –` item appears in the menu bar; its menu has **Quit**, which terminates the app. (Resolve the dependency graph here — `swift build` must fetch OpenMultitouchSupport at the pinned tag with no errors.)

- [ ] **Step 7: Commit**

```bash
git add Package.swift Package.resolved Sources/GlimbleSpike docs/superpowers/notes
git commit -m "feat: add OpenMultitouchSupport dep and menu-bar spike shell"
```

---

### Task 5: Live touch capture — finger count in the menu bar (hardware verification)

Verification task. Proves Phase 0 item #2: raw per-finger frames actually arrive.

**Files:**
- Create: `Sources/GlimbleSpike/TouchReader.swift`
- Modify: `Sources/GlimbleSpike/AppDelegate.swift`

- [ ] **Step 1: Create `TouchReader`**

Use the exact symbols recorded in Task 4 Step 1. The code below assumes `touchDataStream` yields `[OMSTouchData]` and an active touch has `state == .touching`; **adjust both to match the recorded API** if they differ.

`Sources/GlimbleSpike/TouchReader.swift`:

```swift
import Foundation
import OpenMultitouchSupport

/// Isolates ALL private-framework access (via OpenMultitouchSupport) behind one type,
/// emitting only an active-finger count. This is the seed of the Phase 1 `TouchSource` module.
/// Main-actor isolated: the only consumer is the menu-bar UI, and the inherited Task then
/// delivers counts on the main actor with no hop (required by Swift 6 strict concurrency).
@MainActor
final class TouchReader {
    private let manager = OMSManager.shared
    private var task: Task<Void, Never>?

    /// Called on the main actor with the current number of fingers actively touching.
    var onCount: ((Int) -> Void)?

    func start() {
        manager.startListening()
        task = Task { [weak self] in
            guard let self else { return }
            for await touches in self.manager.touchDataStream {
                let active = touches.filter { $0.state == .touching }.count
                self.onCount?(active)   // already on the main actor (inherited)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        manager.stopListening()
    }
}
```

- [ ] **Step 2: Wire it into `AppDelegate` and request Input Monitoring**

Replace `Sources/GlimbleSpike/AppDelegate.swift` with:

```swift
import AppKit
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let touchReader = TouchReader()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "👆 –"

        let menu = NSMenu()
        let quit = NSMenuItem(title: "Quit Glimble Spike",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu

        // Input Monitoring (kTCCServiceListenEvent): force the TCC prompt if not yet granted.
        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
        }

        touchReader.onCount = { [weak self] count in
            self?.statusItem.button?.title = "👆 \(count)"
        }
        touchReader.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        touchReader.stop()
    }
}
```

- [ ] **Step 3: Build and verify capture on the current machine**

Run: `swift build && swift run GlimbleSpike`
Then: grant **Input Monitoring** to the binary when prompted (System Settings ▸ Privacy & Security ▸ Input Monitoring), and **restart the app** (`swift run GlimbleSpike` again — TCC grants apply on next launch).
Expected: resting 2 fingers on the built-in trackpad shows `👆 2`, 3 fingers shows `👆 3`, lifting shows `👆 0`. If it stays `👆 –`/`👆 0` with fingers down, the API symbols differ — recheck Task 4 Step 1.

- [ ] **Step 4: Record the hardware-matrix result**

Append to `docs/superpowers/notes/openmultitouchsupport.md` a "Capture verification" table with one row per machine you can test now (OS version, arch, result). Remaining rows of the 15/26 × Intel/AS matrix are completed in Task 11.

- [ ] **Step 5: Commit**

```bash
git add Sources/GlimbleSpike docs/superpowers/notes/openmultitouchsupport.md
git commit -m "feat: live multitouch finger-count capture in spike"
```

---

### Task 6: AX window snapping + EnhancedUserInterface workaround (app verification)

Verification task. Proves Phase 0 item #4 using the tested `GlimbleCore` geometry.

**Files:**
- Create: `Sources/GlimbleSpike/WindowSnapper.swift`
- Modify: `Sources/GlimbleSpike/AppDelegate.swift`

- [ ] **Step 1: Create `WindowSnapper`**

`Sources/GlimbleSpike/WindowSnapper.swift`:

```swift
import AppKit
import ApplicationServices
import GlimbleCore

enum WindowSnapError: Error {
    case noFrontmostApp
    case noFocusedWindow
    case axError(AXError)
}

/// Snaps the frontmost app's focused window using only the public Accessibility API.
/// Seed of the Phase 1 window-management half of `ActionExecutor`.
/// Main-actor isolated because it reads `NSWorkspace`/`NSScreen` (both `@MainActor`).
@MainActor
enum WindowSnapper {

    static func snapFocusedWindow(to position: SnapPosition) throws {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            throw WindowSnapError.noFrontmostApp
        }
        let axApp = AXUIElementCreateApplication(frontApp.processIdentifier)

        var windowRef: CFTypeRef?
        let windowErr = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef)
        guard windowErr == .success, let windowRef else {
            throw WindowSnapError.noFocusedWindow
        }
        let axWindow = windowRef as! AXUIElement

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let vf = screen.visibleFrame
        let primaryHeight = (NSScreen.screens.first { $0.frame.origin == .zero } ?? screen).frame.height

        let appKitRect = WindowGeometry.snapRect(position, in: vf)
        var axPoint = WindowGeometry.axOrigin(forAppKitRect: appKitRect, primaryHeight: primaryHeight)
        var size = appKitRect.size

        // EnhancedUserInterface workaround (Chrome / Electron / Office): read from the
        // APPLICATION element, disable before resize, restore after.
        let hadEnhancedUI = readEnhancedUserInterface(axApp)
        if hadEnhancedUI { setEnhancedUserInterface(axApp, false) }
        defer { if hadEnhancedUI { setEnhancedUserInterface(axApp, true) } }

        // size → position → size so cross-display moves survive macOS size clamping.
        try setSize(axWindow, &size)
        try setPosition(axWindow, &axPoint)
        try setSize(axWindow, &size)
    }

    private static func setPosition(_ window: AXUIElement, _ point: inout CGPoint) throws {
        guard let value = AXValueCreate(.cgPoint, &point) else { throw WindowSnapError.noFocusedWindow }
        let err = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        if err != .success { throw WindowSnapError.axError(err) }
    }

    private static func setSize(_ window: AXUIElement, _ size: inout CGSize) throws {
        guard let value = AXValueCreate(.cgSize, &size) else { throw WindowSnapError.noFocusedWindow }
        let err = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        if err != .success { throw WindowSnapError.axError(err) }
    }

    private static func readEnhancedUserInterface(_ axApp: AXUIElement) -> Bool {
        var current: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, &current)
        return (current as? Bool) ?? false
    }

    private static func setEnhancedUserInterface(_ axApp: AXUIElement, _ enabled: Bool) {
        let value: CFTypeRef = enabled ? kCFBooleanTrue : kCFBooleanFalse
        AXUIElementSetAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, value)
    }
}
```

- [ ] **Step 2: Add snap menu items + Accessibility prompt to `AppDelegate`**

In `Sources/GlimbleSpike/AppDelegate.swift`, add `import ApplicationServices` at the top. In `applicationDidFinishLaunching`, insert these menu items **before** the Quit item, and prompt for Accessibility:

```swift
        let snapLeft  = NSMenuItem(title: "Snap Left",  action: #selector(snapLeft),  keyEquivalent: "")
        let snapRight = NSMenuItem(title: "Snap Right", action: #selector(snapRight), keyEquivalent: "")
        let maximize  = NSMenuItem(title: "Maximize",   action: #selector(maximize),  keyEquivalent: "")
        for item in [snapLeft, snapRight, maximize] {
            item.target = self          // accessory apps aren't reliably in the responder chain
            menu.addItem(item)
        }
        menu.addItem(.separator())

        // Accessibility (kTCCServiceAccessibility): needed to set window position/size.
        // kAXTrustedCheckOptionPrompt == "AXTrustedCheckOptionPrompt"; the string literal
        // avoids referencing the non-concurrency-safe global CFString under Swift 6.
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
```

Add these action methods to the class:

```swift
    @objc private func snapLeft()  { try? WindowSnapper.snapFocusedWindow(to: .left) }
    @objc private func snapRight() { try? WindowSnapper.snapFocusedWindow(to: .right) }
    @objc private func maximize()  { try? WindowSnapper.snapFocusedWindow(to: .maximize) }
```

- [ ] **Step 3: Build and verify snapping**

Run: `swift build && swift run GlimbleSpike`
Then grant **Accessibility** (System Settings ▸ Privacy & Security ▸ Accessibility) and relaunch.
Expected:
- Focus **TextEdit**, choose **Snap Left** → window fills the left half under the menu bar; **Maximize** → fills the visible frame.
- Focus **Google Chrome**, choose **Snap Right** → window snaps cleanly to the right half (this is the EnhancedUserInterface case; without the workaround Chrome resizes incorrectly or not at all).

- [ ] **Step 4: Record the result**

Append a "Window snapping" section to the notes file: TextEdit result, Chrome result, and whether the EnhancedUserInterface workaround was observed to matter.

- [ ] **Step 5: Commit**

```bash
git add Sources/GlimbleSpike docs/superpowers/notes/openmultitouchsupport.md
git commit -m "feat: AX window snapping with EnhancedUserInterface workaround"
```

---

### Task 7: Bundle assembly + Developer ID signing (Hardened Runtime)

Verification task. Produces a signed `.app` and proves it passes local Gatekeeper assessment before notarization.

**Files:**
- Create: `Glimble.entitlements`
- Create: `scripts/build-app.sh`

- [ ] **Step 1: Create the entitlements file**

Exactly one relaxation, per the spec. `Glimble.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 2: Create the build/sign script**

`scripts/build-app.sh`:

```bash
#!/bin/bash
set -euo pipefail

IDENTITY="${GLIMBLE_IDENTITY:?Set GLIMBLE_IDENTITY to your 'Developer ID Application: NAME (TEAMID)' string}"
CONFIG=release
APP="Glimble Spike.app"
BIN=".build/${CONFIG}/GlimbleSpike"

swift build -c "${CONFIG}" --product GlimbleSpike

rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BIN}" "${APP}/Contents/MacOS/GlimbleSpike"
cp Sources/GlimbleSpike/Info.plist "${APP}/Contents/Info.plist"

# If OpenMultitouchSupport linked an embedded framework/dylib (binaryTarget case from
# Task 4 Step 1), sign those FIRST, inside-out. No-op when nothing matches.
if [ -d "${APP}/Contents/Frameworks" ]; then
  find "${APP}/Contents/Frameworks" -type f \( -name "*.dylib" -o -name "*" -path "*.framework/*" \) -print0 \
    | while IFS= read -r -d '' f; do
        codesign --force --options runtime --timestamp --sign "${IDENTITY}" "${f}"
      done
fi

# Sign the app LAST, with Hardened Runtime + entitlements. Never use --deep.
codesign --force --options runtime --timestamp \
  --entitlements Glimble.entitlements \
  --sign "${IDENTITY}" "${APP}"

codesign --verify --strict --verbose=2 "${APP}"
echo "Signed ${APP}"
```

- [ ] **Step 3: Run the build/sign script**

Run: `chmod +x scripts/build-app.sh && GLIMBLE_IDENTITY="$IDENTITY" ./scripts/build-app.sh`
(`$IDENTITY` = the exact Developer ID string from Prerequisites.)
Expected: ends with `Signed Glimble Spike.app` and no codesign errors.

- [ ] **Step 4: Verify signing and local Gatekeeper assessment**

Run: `codesign -dvvv "Glimble Spike.app" 2>&1 | grep -E "Authority|flags|Identifier"`
Expected: `Authority=Developer ID Application: …`, and `flags=…runtime…` (Hardened Runtime present).

Run: `codesign -d --entitlements - "Glimble Spike.app"`
Expected: shows `com.apple.security.cs.disable-library-validation` = true and nothing else.

- [ ] **Step 5: Commit**

```bash
git add Glimble.entitlements scripts/build-app.sh
git commit -m "build: Developer ID signing with hardened runtime for spike app"
```

---

### Task 8: Notarization + staple

Verification task. **This is the central bet** — that a private-framework-linking app clears Apple's notary service.

**Files:**
- Create: `scripts/notarize.sh`

- [ ] **Step 1: Create the notarization script**

`scripts/notarize.sh`:

```bash
#!/bin/bash
set -euo pipefail

APP="Glimble Spike.app"
ZIP="GlimbleSpike.zip"
PROFILE="${GLIMBLE_NOTARY_PROFILE:-glimble-notary}"

ditto -c -k --keepParent "${APP}" "${ZIP}"

xcrun notarytool submit "${ZIP}" --keychain-profile "${PROFILE}" --wait

xcrun stapler staple "${APP}"
xcrun stapler validate "${APP}"
spctl -a -t exec -vv "${APP}"
```

- [ ] **Step 2: Run notarization**

Run: `chmod +x scripts/notarize.sh && ./scripts/notarize.sh`
Expected: `notarytool` prints `status: Accepted`; `stapler validate` prints `The validate action worked!`; `spctl` prints `source=Notarized Developer ID` and `accepted`.

- [ ] **Step 3: If notarization is REJECTED, capture the log and stop**

Run: `xcrun notarytool log <submission-id> --keychain-profile "$GLIMBLE_NOTARY_PROFILE"`
Record the full JSON in `docs/superpowers/notes/openmultitouchsupport.md` under "Notarization". A rejection here is a **gate failure** for the whole project — do not proceed to Phase 1; surface it for a go/no-go decision.

- [ ] **Step 4: Commit**

```bash
git add scripts/notarize.sh docs/superpowers/notes/openmultitouchsupport.md
git commit -m "build: notarization + staple script for spike app"
```

---

### Task 9: Clean-machine Gatekeeper launch test

Verification task. Confirms a downloaded copy launches without the private framework tripping Gatekeeper on a machine that never built it.

**Files:** none (manual verification; result recorded in notes).

- [ ] **Step 1: Transfer the stapled app to a clean macOS 26 machine**

Copy `GlimbleSpike.zip` (the stapled app re-zipped, or the `.app` via an external volume / download) to a clean macOS 26 machine that has never run `swift build` for this project and does not have it in TCC.

- [ ] **Step 2: Launch and confirm Gatekeeper acceptance**

On the clean machine, unzip and double-click `Glimble Spike.app`.
Expected: it launches with **no** "cannot be opened because the developer cannot be verified" block (stapling makes this work offline); the `👆 –` menu-bar item appears. Granting Input Monitoring then shows live finger counts.

Run (on the clean machine): `spctl -a -t exec -vv "/path/to/Glimble Spike.app"`
Expected: `accepted`, `source=Notarized Developer ID`.

- [ ] **Step 3: Record the result**

Add a "Clean-machine launch (macOS 26)" line to the notes: pass/fail + the `spctl` output.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/notes/openmultitouchsupport.md
git commit -m "docs: record clean-machine Gatekeeper launch result"
```

---

### Task 10: Hardware capture matrix

Verification task. Completes Phase 0 item #2 across the OS × arch matrix.

**Files:** none beyond the notes table.

- [ ] **Step 1: Run the signed app on each available target machine**

On each of macOS 15/Intel, macOS 15/Apple Silicon, macOS 26/Intel, macOS 26/Apple Silicon that you can access: grant Input Monitoring, rest 2–4 fingers, observe the count.

- [ ] **Step 2: Fill the matrix**

Complete the capture table in `docs/superpowers/notes/openmultitouchsupport.md`: one row per cell, each marked pass / fail / not-available, with the OS point version. **Any cell where frames do not arrive is a Phase 0 finding** — note it explicitly rather than leaving the cell blank.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/notes/openmultitouchsupport.md
git commit -m "docs: record multitouch capture matrix across OS/arch"
```

---

### Task 11: Phase 0 gate decision

Verification task. Consolidates the spike outcomes into an explicit go/no-go for Phase 1.

**Files:**
- Create: `docs/superpowers/notes/phase0-gate.md`

- [ ] **Step 1: Write the gate summary**

Create `docs/superpowers/notes/phase0-gate.md` recording, from the recorded results (not assumptions), the verdict for each gate item:

```markdown
# Phase 0 Gate — Results

| # | Bet | Result | Evidence |
|---|-----|--------|----------|
| 1 | Notarization passes with private framework | PASS/FAIL | Task 8 status, log id |
| 2 | Touch frames arrive (15/26 × Intel/AS) | PASS/FAIL/PARTIAL | Task 10 matrix |
| 3 | Package version/license/toolchain confirmed | PASS/FAIL | Task 4 notes |
| 4 | AX snap + Chrome workaround works | PASS/FAIL | Task 6 notes |
| 5 | Clean-machine Gatekeeper launch | PASS/FAIL | Task 9 notes |

## Decision
GO / NO-GO for Phase 1, with rationale. List any cell that was PARTIAL/FAIL and the
mitigation or open question it creates for the Phase 1 plan.
```

- [ ] **Step 2: Fill in the verdict and decision** from the recorded evidence in the notes file.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/notes/phase0-gate.md
git commit -m "docs: Phase 0 risk-burndown gate decision"
```

---

## Self-Review

**Spec coverage (against Phase 0 in the design spec):**
- Phase 0 item #1 (notarization + Gatekeeper on clean macOS 26) → Tasks 7, 8, 9. ✅
- Phase 0 item #2 (touch frames on 15/26 × Intel/AS) → Tasks 5, 10. ✅
- Phase 0 item #3 (exact pinned version/license/toolchain) → Task 4 Step 1. ✅
- Phase 0 item #4 (AX snap + EnhancedUserInterface workaround vs Chrome) → Tasks 2, 3, 6. ✅
- Spec architecture seeds (TouchSource isolation, pure testable geometry, single relaxation entitlement, LSUIElement, size→position→size, coordinate flip) are each reflected in a task.

**Out of Phase 0 scope (correctly deferred to the Phase 1 plan):** RuleStore/JSON config, GestureRecognizer state machine + arbiter, AppContext scoping, full ActionExecutor (keystrokes/scripts/app launch), PermissionsCoordinator recovery flow, onboarding UI, Sparkle, SMAppService, Xcode project migration, drawn shapes / Force-Touch / rotate / external devices.

**Placeholder scan:** the only parameterized token is `X.Y.Z` (the dependency tag) and `$IDENTITY`/profile — each has an explicit discovery command, so they are resolved at execution time, not vague TODOs. No "add error handling"/"write tests for the above" placeholders.

**Type consistency:** `SnapPosition` (Task 1) is consumed unchanged by `WindowGeometry.snapRect`/`axOrigin` (Tasks 2–3) and `WindowSnapper.snapFocusedWindow(to:)` (Task 6). `TouchReader.onCount: (Int) -> Void` (Task 5) matches its `AppDelegate` consumer. `WindowGeometry.axOrigin(forAppKitRect:primaryHeight:)` signature is identical in Task 3 definition and Task 6 call site.

**TDD vs verification:** Tasks 1–3 are genuine red/green TDD. Tasks 4–11 are verification tasks (hardware, signing, notarization) where a failing-first unit test is impossible — each instead has exact commands, expected output, and a recorded result. Flagged explicitly so this is a deliberate choice, not a missing-test gap.
