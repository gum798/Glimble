# OpenMultitouchSupport — dependency facts (Phase 0 spike, Task 4)

Recorded from what was actually observed at the pinned tag (not assumptions).
Source: https://github.com/Kyome22/OpenMultitouchSupport

## Pinned version
- **Tag: `4.0.0`** (highest semver from `git ls-remote --tags`; full tag list was
  1.0, 1.1, 2.0.0, 3.0.0, 3.0.1, 3.0.2, 3.0.3, 4.0.0).
- Pinned with `exact: "4.0.0"` in `Package.swift`.

## License
- **MIT License** — `Copyright (c) 2019 TakutoNakamura`. OK to use. (NOT GPL.)

## Manifest facts (its Package.swift @ 4.0.0)
- **`swift-tools-version: 6.2`** (NOTE: newer than Glimble's own `6.0`. This is fine
  because a consumer package's tools-version does not need to match a dependency's;
  it only requires a toolchain new enough to parse 6.2. Our toolchain is Swift 6.3.2 /
  Xcode 26.5, so it resolves & builds. Verified by `swift build` succeeding.)
- **Minimum platform: macOS `.v15`** (matches Glimble's `.macOS(.v15)`).
- Upstream dependency: `swift-async-algorithms` (from 1.1.4) — transitively pulled in.
- Enables upcoming feature `ExistentialAny`.

## Product to depend on
- **Product name: `OpenMultitouchSupport`** (library product).
- Package identity used in `.product(name:package:)`: `OpenMultitouchSupport`.

## Source vs binary target  (MATTERS FOR LATER SIGNING/NOTARIZATION)
- The product is **NOT a pure source target.** It is a thin Swift source target
  (`OpenMultitouchSupport`) that wraps a **`binaryTarget` XCFramework**:
  - `binaryTarget` name: `OpenMultitouchSupportXCF`
  - URL: `.../releases/download/4.0.0/OpenMultitouchSupportXCF.xcframework.zip`
  - checksum: `270d0b70d2dfa935f846b54d53004ec8bd6a0588996f56a0c06e5b39bab5afd4`
- The XCFramework wraps an Objective-C/C implementation that talks to the private
  `MultitouchSupport.framework`. The Swift layer (`OMSManager`, `OMSTouchData`,
  `OMSState`) imports `OpenMultitouchSupportXCF`.
- **Signing implication:** because we ship a prebuilt XCFramework binary (not source we
  compile ourselves), the embedded binary must be re-signed when we sign/notarize the
  Glimble app bundle (deep/`--options runtime` signing must cover the bundled
  framework). Plan for this in the packaging/notarization task.
- **Sandbox implication:** README states "App SandBox must be disabled to use
  OpenMultitouchSupport" — it relies on a private framework, so a sandboxed/
  Mac-App-Store distribution is not possible. Distribute as Developer-ID + notarized,
  outside the App Store.

## Exact public API (verbatim from Sources/OpenMultitouchSupport @ 4.0.0)
- Manager accessor: **`OMSManager.shared`** — a `public static let` **property**
  (`public final class OMSManager: Sendable`).
  - CAUTION: the README example writes `OMSManager.shared()` (with parens) — that is
    WRONG / stale. The real source is a property: `OMSManager.shared` (no parens).
    The `()` form in the README mirrors the underlying Obj-C `OpenMTManager.shared()`,
    not the Swift wrapper. Use `OMSManager.shared`.
- Start: **`func startListening() -> Bool`** (`@discardableResult`).
- Stop:  **`func stopListening() -> Bool`** (`@discardableResult`).
- Also: `var isListening: Bool`.
- Stream property: **`var touchDataStream`**.
  - Element type: **`[OMSTouchData]`** — an ARRAY of touches per emission (NOT a single
    `OMSTouchData`). Empty array `[]` is sent when all fingers lift.
  - Type: `any AsyncShareStream<[OMSTouchData]>` where
    `AsyncShareStream<T> = Sendable & AsyncSequence<T, ...>` (a shared/multicast async
    sequence backed by AsyncAlgorithms `.share()`). Consume with `for await`.
- Active-touch `state` case: **`OMSState.touching`** is the case meaning "actively
  touching." Full enum (`OMSState: String`): `notTouching, starting, hovering, making,
  touching, breaking, lingering, leaving`.

### Minimal usage shape (for the LATER touch-capture task, NOT this one)
```swift
import OpenMultitouchSupport
let manager = OMSManager.shared
Task {
    for await touches in manager.touchDataStream {   // touches: [OMSTouchData]
        let active = touches.filter { $0.state == .touching }
        // ...
    }
}
manager.startListening()
// manager.stopListening()
```

## Touch data fields (OMSTouchData)
`id: Int32`, `position: OMSPosition(x,y: Float)`, `total: Float`, `pressure: Float`,
`axis: OMSAxis(major,minor: Float)`, `angle: Float`, `density: Float`,
`state: OMSState`, `timestamp: String`.
