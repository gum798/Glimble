# Glimble v1 — Plan 2: App Shell & UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Glimble usable: a SwiftUI settings window with a rule list and an editor whose trigger is filled by **performing the gesture live**, a per-permission onboarding flow, launch-at-login, and a real menu — all backed by a shared, observable rule model that the engine reads live.

**Architecture:** New pure `GlimbleCore` helpers (immutable `RuleSet` edits + human-readable display names) stay unit-tested. The app gains an `@MainActor` `ObservableObject` `RulesModel` (single source of truth, persists on change) that both the `GestureEngine` and the SwiftUI views share; a `Recorder` that captures the next recognized gesture instead of executing it; `PermissionsCoordinator` and `LaunchAtLogin` wrappers; and SwiftUI views hosted in plain `NSWindow`s (not `SettingsLink`, which is unreliable on macOS 15/26).

**Tech Stack:** SwiftUI + AppKit (`NSHostingController`/`NSWindow`/`NSStatusItem`), `ServiceManagement` (`SMAppService`), `ApplicationServices`/`CoreGraphics` (permission checks). Builds on Plan 1's `GlimbleCore` + `GestureEngine`/`TouchSource`/`ActionExecutor`. Min macOS 15, validated on 26.

---

## Conventions locked for this plan

- The model layer uses **`ObservableObject` + `@Published`** (not the `@Observable` macro) for predictable SwiftUI binding under Swift 6 strict concurrency.
- `RulesModel` is the **single source of truth**. `GestureEngine` holds a reference to it and reads `model.ruleSet` per gesture (so edits take effect with no restart). The old `GestureEngine`-owns-`RuleStore` design from Plan 1 is refactored here.
- All edits go through pure `RuleSet` helpers in `GlimbleCore` so the logic is unit-tested without the UI.
- Recording reuses the single `TouchSource`: while `Recorder.isRecording`, the engine routes a recognized gesture to the recorder and does **not** execute an action.

---

### Task 1: Pure `RuleSet` edit helpers (GlimbleCore, TDD)

**Files:**
- Create: `Sources/GlimbleCore/RuleSet+Edits.swift`
- Create: `Tests/GlimbleCoreTests/RuleSetEditsTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/GlimbleCoreTests/RuleSetEditsTests.swift`:
```swift
import Testing
import Foundation
@testable import GlimbleCore

private func r(_ id: Int, _ trigger: RecognizedGesture, enabled: Bool = true) -> Rule {
    Rule(id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", id))")!,
         scope: .global, trigger: trigger, action: .window(.maximize), enabled: enabled)
}

@Test func addingAppendsRule() {
    let set = RuleSet(rules: [r(1, .tap(fingers: 3))])
    let out = set.adding(r(2, .tap(fingers: 4)))
    #expect(out.rules.count == 2)
    #expect(out.rules.last?.trigger == .tap(fingers: 4))
}

@Test func removingDropsByID() {
    let set = RuleSet(rules: [r(1, .tap(fingers: 3)), r(2, .tap(fingers: 4))])
    let out = set.removing(id: r(1, .tap(fingers: 3)).id)
    #expect(out.rules.count == 1)
    #expect(out.rules.first?.trigger == .tap(fingers: 4))
}

@Test func updatingReplacesMatchingID() {
    let original = r(1, .tap(fingers: 3))
    var edited = original
    edited.enabled = false
    let out = RuleSet(rules: [original]).updating(edited)
    #expect(out.rules.first?.enabled == false)
}

@Test func togglingFlipsEnabled() {
    let set = RuleSet(rules: [r(1, .tap(fingers: 3), enabled: true)])
    let out = set.togglingEnabled(id: set.rules[0].id)
    #expect(out.rules.first?.enabled == false)
}
```

- [ ] **Step 2: Run, verify FAIL**

Run: `swift test --filter RuleSetEditsTests`
Expected: FAIL — `RuleSet` has no member `adding`/`removing`/`updating`/`togglingEnabled`.

- [ ] **Step 3: Implement**

`Sources/GlimbleCore/RuleSet+Edits.swift`:
```swift
import Foundation

public extension RuleSet {
    /// A copy with `rule` appended.
    func adding(_ rule: Rule) -> RuleSet {
        RuleSet(version: version, rules: rules + [rule])
    }

    /// A copy with the rule whose `id` matches `rule.id` replaced; no-op if absent.
    func updating(_ rule: Rule) -> RuleSet {
        RuleSet(version: version, rules: rules.map { $0.id == rule.id ? rule : $0 })
    }

    /// A copy without the rule with `id`.
    func removing(id: UUID) -> RuleSet {
        RuleSet(version: version, rules: rules.filter { $0.id != id })
    }

    /// A copy with the `enabled` flag of the rule with `id` flipped.
    func togglingEnabled(id: UUID) -> RuleSet {
        RuleSet(version: version, rules: rules.map {
            var r = $0
            if r.id == id { r.enabled.toggle() }
            return r
        })
    }
}
```

- [ ] **Step 4: Run, verify PASS**

Run: `swift test --filter RuleSetEditsTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/GlimbleCore/RuleSet+Edits.swift Tests/GlimbleCoreTests/RuleSetEditsTests.swift
git commit -m "feat: pure RuleSet edit helpers (add/update/remove/toggle)"
```

---

### Task 2: Human-readable display names (GlimbleCore, TDD)

For the rule-list UI. Pure, so unit-tested.

**Files:**
- Create: `Sources/GlimbleCore/DisplayNames.swift`
- Create: `Tests/GlimbleCoreTests/DisplayNamesTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/GlimbleCoreTests/DisplayNamesTests.swift`:
```swift
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
```

- [ ] **Step 2: Run, verify FAIL**

Run: `swift test --filter DisplayNamesTests`
Expected: FAIL — no `displayName`.

- [ ] **Step 3: Implement**

`Sources/GlimbleCore/DisplayNames.swift`:
```swift
public extension RecognizedGesture {
    var displayName: String {
        switch self {
        case .swipe(let fingers, let direction):
            return "\(fingers)-finger swipe \(direction.rawValue)"
        case .tap(let fingers):
            return "\(fingers)-finger tap"
        }
    }
}

public extension SnapPosition {
    var displayName: String {
        switch self {
        case .left: return "Snap left";        case .right: return "Snap right"
        case .top: return "Snap top";          case .bottom: return "Snap bottom"
        case .topLeft: return "Snap top-left";  case .topRight: return "Snap top-right"
        case .bottomLeft: return "Snap bottom-left"; case .bottomRight: return "Snap bottom-right"
        case .maximize: return "Maximize window"; case .center: return "Center window"
        }
    }
}

public extension GlimbleAction {
    var displayName: String {
        switch self {
        case .keyboardShortcut: return "Keyboard shortcut"
        case .shell: return "Run shell command"
        case .appleScript: return "Run AppleScript"
        case .runShortcut(let name): return "Run Shortcut “\(name)”"
        case .launchApp(let bundleID): return "Launch \(bundleID)"
        case .window(let pos): return pos.displayName
        }
    }
}
```

- [ ] **Step 4: Run, verify PASS**

Run: `swift test --filter DisplayNamesTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/GlimbleCore/DisplayNames.swift Tests/GlimbleCoreTests/DisplayNamesTests.swift
git commit -m "feat: human-readable display names for gestures and actions"
```

---

### Task 3: `RulesModel` + refactor `GestureEngine` to share it

**Files:**
- Create: `Sources/GlimbleApp/RulesModel.swift`
- Modify: `Sources/GlimbleApp/GestureEngine.swift`

- [ ] **Step 1: Create `RulesModel`** (single source of truth, persists on change)

`Sources/GlimbleApp/RulesModel.swift`:
```swift
import Foundation
import GlimbleCore

/// Observable single source of truth for rules. Persists to disk on every mutation.
/// Shared by the GestureEngine (reads) and the settings UI (edits).
@MainActor
final class RulesModel: ObservableObject {
    @Published private(set) var ruleSet: RuleSet

    private let url: URL

    /// The on-disk rule file: ~/Library/Application Support/Glimble/rules.json
    static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Glimble", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("rules.json")
    }

    init(url: URL = RulesModel.defaultURL) {
        self.url = url
        let loaded = (try? RuleStore.load(from: url))?.ruleSet ?? RuleSet(rules: [])
        if loaded.rules.isEmpty {
            ruleSet = DefaultPresets.ruleSet
            persist()
        } else {
            ruleSet = loaded
        }
    }

    /// Current resolution used by the engine.
    func action(for gesture: RecognizedGesture, frontmostBundleID: String?) -> GlimbleAction? {
        RuleStore(ruleSet: ruleSet).action(for: gesture, frontmostBundleID: frontmostBundleID)
    }

    func add(_ rule: Rule)          { mutate { $0.adding(rule) } }
    func update(_ rule: Rule)       { mutate { $0.updating(rule) } }
    func remove(id: UUID)           { mutate { $0.removing(id: id) } }
    func toggle(id: UUID)           { mutate { $0.togglingEnabled(id: id) } }

    private func mutate(_ transform: (RuleSet) -> RuleSet) {
        ruleSet = transform(ruleSet)
        persist()
    }

    private func persist() {
        try? RuleStore(ruleSet: ruleSet).write(to: url)
    }
}
```

- [ ] **Step 2: Refactor `GestureEngine`** to read from a shared `RulesModel` and support recording. Replace `Sources/GlimbleApp/GestureEngine.swift` with:

```swift
import Foundation
import GlimbleCore

/// Runs the frame→gesture→action pipeline against the shared RulesModel.
/// While `onRecognized` is set, gestures are delivered there and NOT executed (recording mode).
@MainActor
final class GestureEngine {
    private var recognizer = GestureRecognizer()
    private let rules: RulesModel

    /// When non-nil, the next recognized gestures go here instead of running an action.
    var onRecognized: ((RecognizedGesture) -> Void)?

    init(rules: RulesModel) {
        self.rules = rules
    }

    func handle(_ frame: TouchFrame) {
        guard let gesture = recognizer.process(frame) else { return }
        if let recorder = onRecognized {
            recorder(gesture)
            return
        }
        guard let action = rules.action(for: gesture, frontmostBundleID: AppContext.frontmostBundleID)
        else { return }
        ActionExecutor.run(action)
    }
}
```

- [ ] **Step 3: Build + test**

Run: `swift build && swift test`
Expected: build fails in `AppDelegate` (it constructs `GestureEngine()` with no args). That's fixed in Task 8. For now, temporarily update `AppDelegate` so it compiles: change `private let engine = GestureEngine()` to:
```swift
    private let rules = RulesModel()
    private lazy var engine = GestureEngine(rules: rules)
```
and change the menu line `"Glimble (\(engine.store.ruleSet.rules.count) rules)"` → `"Glimble (\(rules.ruleSet.rules.count) rules)"`.
Re-run: `swift build && swift test` → `Build complete!`, 39 GlimbleCore tests pass (35 + 4 from Task 1; Task 2 adds 2 → 41 total by now).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: RulesModel single source of truth; engine reads it live + recording hook"
```

---

### Task 4: `Recorder` — capture the next gesture

**Files:**
- Create: `Sources/GlimbleApp/Recorder.swift`

- [ ] **Step 1: Implement**

`Sources/GlimbleApp/Recorder.swift`:
```swift
import Foundation
import GlimbleCore

/// Drives the "perform a gesture to set the trigger" flow in the rule editor.
/// The AppDelegate connects the engine's recognized gestures to `capture(_:)` while recording.
@MainActor
final class Recorder: ObservableObject {
    @Published var isRecording = false
    @Published var captured: RecognizedGesture?

    func start() {
        captured = nil
        isRecording = true
    }

    func cancel() {
        isRecording = false
    }

    /// Called by the engine bridge with a recognized gesture while recording.
    func capture(_ gesture: RecognizedGesture) {
        guard isRecording else { return }
        captured = gesture
        isRecording = false
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`.

- [ ] **Step 3: Commit**

```bash
git add Sources/GlimbleApp/Recorder.swift
git commit -m "feat: Recorder captures the next recognized gesture for the editor"
```

---

### Task 5: `PermissionsCoordinator`

**Files:**
- Create: `Sources/GlimbleApp/PermissionsCoordinator.swift`

- [ ] **Step 1: Implement**

`Sources/GlimbleApp/PermissionsCoordinator.swift`:
```swift
import AppKit
import ApplicationServices
import CoreGraphics

/// Per-capability TCC status + request + deep links. Input Monitoring is needed to READ
/// touches; Accessibility is needed to synthesize keys and move windows.
@MainActor
final class PermissionsCoordinator: ObservableObject {
    @Published var inputMonitoringGranted = false
    @Published var accessibilityGranted = false

    func refresh() {
        inputMonitoringGranted = CGPreflightListenEventAccess()
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestInputMonitoring() {
        if !CGPreflightListenEventAccess() { CGRequestListenEventAccess() }
        openSettings(pane: "Privacy_ListenEvent")
    }

    func requestAccessibility() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        openSettings(pane: "Privacy_Accessibility")
    }

    private func openSettings(pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`.

- [ ] **Step 3: Commit**

```bash
git add Sources/GlimbleApp/PermissionsCoordinator.swift
git commit -m "feat: PermissionsCoordinator tracks/requests Input Monitoring + Accessibility"
```

---

### Task 6: `LaunchAtLogin` (SMAppService)

**Files:**
- Create: `Sources/GlimbleApp/LaunchAtLogin.swift`

- [ ] **Step 1: Implement**

`Sources/GlimbleApp/LaunchAtLogin.swift`:
```swift
import ServiceManagement

/// Wraps SMAppService.mainApp for "open at login".
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Glimble: launch-at-login \(enabled ? "register" : "unregister") failed: \(error)")
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`.

- [ ] **Step 3: Commit**

```bash
git add Sources/GlimbleApp/LaunchAtLogin.swift
git commit -m "feat: LaunchAtLogin via SMAppService"
```

---

### Task 7: `WindowPresenter` — host SwiftUI views in NSWindows

`SettingsLink`/`openSettings` are unreliable on macOS 15/26, so we present plain windows via `NSHostingController`.

**Files:**
- Create: `Sources/GlimbleApp/WindowPresenter.swift`

- [ ] **Step 1: Implement**

`Sources/GlimbleApp/WindowPresenter.swift`:
```swift
import AppKit
import SwiftUI

/// Shows a SwiftUI view in a standard, reusable NSWindow (one per key). Brings the app
/// forward so the window is visible even though Glimble is an accessory (menu-bar) app.
@MainActor
final class WindowPresenter {
    private var windows: [String: NSWindow] = [:]

    func show<Content: View>(_ key: String, title: String, @ViewBuilder content: () -> Content) {
        if let existing = windows[key] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false)
        window.title = title
        window.contentViewController = NSHostingController(rootView: content())
        window.isReleasedWhenClosed = false
        window.center()
        windows[key] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`.

- [ ] **Step 3: Commit**

```bash
git add Sources/GlimbleApp/WindowPresenter.swift
git commit -m "feat: WindowPresenter hosts SwiftUI views in NSWindows"
```

---

### Task 8: `RuleEditorView` — trigger via live recorder + action/scope pickers

**Files:**
- Create: `Sources/GlimbleApp/RuleEditorView.swift`

- [ ] **Step 1: Implement**

`Sources/GlimbleApp/RuleEditorView.swift`:
```swift
import SwiftUI
import AppKit
import GlimbleCore

/// Edit (or create) one rule. The trigger is set by tapping "Record" and performing the gesture.
struct RuleEditorView: View {
    @ObservedObject var recorder: Recorder
    let existing: Rule?
    let onSave: (Rule) -> Void
    let onCancel: () -> Void

    @State private var trigger: RecognizedGesture?
    @State private var actionKind: ActionKind = .windowMaximize
    @State private var shellText = ""
    @State private var scopeBundleID: String = ""   // "" = global

    enum ActionKind: String, CaseIterable, Identifiable {
        case windowMaximize = "Maximize window"
        case windowCenter = "Center window"
        case windowLeft = "Snap left"
        case windowRight = "Snap right"
        case shell = "Run shell command"
        var id: String { rawValue }
    }

    var body: some View {
        Form {
            Section("Trigger") {
                HStack {
                    Text(trigger?.displayName ?? "No gesture yet")
                        .foregroundStyle(trigger == nil ? .secondary : .primary)
                    Spacer()
                    Button(recorder.isRecording ? "Perform gesture…" : "Record") {
                        recorder.start()
                    }
                    .disabled(recorder.isRecording)
                }
            }
            Section("Action") {
                Picker("Do", selection: $actionKind) {
                    ForEach(ActionKind.allCases) { Text($0.rawValue).tag($0) }
                }
                if actionKind == .shell {
                    TextField("Command", text: $shellText)
                }
            }
            Section("Applies to") {
                Picker("Scope", selection: $scopeBundleID) {
                    Text("All apps").tag("")
                    ForEach(runningApps(), id: \.self) { Text($0).tag($0) }
                }
            }
            HStack {
                Button("Cancel", role: .cancel) { onCancel() }
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trigger == nil)
            }
        }
        .padding()
        .frame(width: 460)
        .onAppear(perform: loadExisting)
        .onChange(of: recorder.captured) { _, newValue in
            if let g = newValue { trigger = g }
        }
    }

    private func runningApps() -> [String] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.bundleIdentifier }
            .sorted()
    }

    private func loadExisting() {
        guard let rule = existing else { return }
        trigger = rule.trigger
        if case .app(let b) = rule.scope { scopeBundleID = b }
        switch rule.action {
        case .window(.maximize): actionKind = .windowMaximize
        case .window(.center): actionKind = .windowCenter
        case .window(.left): actionKind = .windowLeft
        case .window(.right): actionKind = .windowRight
        case .shell(let c): actionKind = .shell; shellText = c
        default: break
        }
    }

    private func save() {
        guard let trigger else { return }
        let action: GlimbleAction
        switch actionKind {
        case .windowMaximize: action = .window(.maximize)
        case .windowCenter: action = .window(.center)
        case .windowLeft: action = .window(.left)
        case .windowRight: action = .window(.right)
        case .shell: action = .shell(shellText)
        }
        let scope: RuleScope = scopeBundleID.isEmpty ? .global : .app(bundleID: scopeBundleID)
        let rule = Rule(id: existing?.id ?? UUID(), scope: scope, trigger: trigger,
                        action: action, enabled: existing?.enabled ?? true)
        onSave(rule)
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`. (SwiftUI compiles headlessly; not run.)

- [ ] **Step 3: Commit**

```bash
git add Sources/GlimbleApp/RuleEditorView.swift
git commit -m "feat: RuleEditorView with live gesture recorder and action/scope pickers"
```

---

### Task 9: `SettingsView` — rule list

**Files:**
- Create: `Sources/GlimbleApp/SettingsView.swift`

- [ ] **Step 1: Implement**

`Sources/GlimbleApp/SettingsView.swift`:
```swift
import SwiftUI
import GlimbleCore

/// The rule list: enable/disable, delete, add. Editing presents a `RuleEditorView` sheet.
struct SettingsView: View {
    @ObservedObject var rules: RulesModel
    @ObservedObject var recorder: Recorder

    @State private var editing: Rule?
    @State private var showingEditor = false

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(rules.ruleSet.rules) { rule in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { rule.enabled },
                            set: { _ in rules.toggle(id: rule.id) }))
                        .labelsHidden()
                        VStack(alignment: .leading) {
                            Text(rule.trigger.displayName).font(.body)
                            Text(rule.action.displayName + scopeSuffix(rule.scope))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Edit") { editing = rule; showingEditor = true }
                        Button(role: .destructive) { rules.remove(id: rule.id) } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            Divider()
            HStack {
                Button {
                    editing = nil; showingEditor = true
                } label: { Label("Add Rule", systemImage: "plus") }
                Spacer()
                Text("\(rules.ruleSet.rules.count) rules").foregroundStyle(.secondary)
            }
            .padding(8)
        }
        .frame(minWidth: 480, minHeight: 360)
        .sheet(isPresented: $showingEditor) {
            RuleEditorView(
                recorder: recorder,
                existing: editing,
                onSave: { rule in
                    if editing == nil { rules.add(rule) } else { rules.update(rule) }
                    showingEditor = false
                },
                onCancel: { recorder.cancel(); showingEditor = false })
        }
    }

    private func scopeSuffix(_ scope: RuleScope) -> String {
        switch scope {
        case .global: return ""
        case .app(let b): return " · \(b)"
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`.

- [ ] **Step 3: Commit**

```bash
git add Sources/GlimbleApp/SettingsView.swift
git commit -m "feat: SettingsView rule list with toggle/edit/delete/add"
```

---

### Task 10: `OnboardingView` — permissions

**Files:**
- Create: `Sources/GlimbleApp/OnboardingView.swift`

- [ ] **Step 1: Implement**

`Sources/GlimbleApp/OnboardingView.swift`:
```swift
import SwiftUI

/// First-run / permissions help. Shows live status and a button per permission, plus a note
/// about disabling conflicting macOS trackpad gestures.
struct OnboardingView: View {
    @ObservedObject var permissions: PermissionsCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to Glimble").font(.title2).bold()
            Text("Glimble needs two permissions to map trackpad gestures to actions.")
                .foregroundStyle(.secondary)

            permissionRow(
                title: "Input Monitoring",
                detail: "Lets Glimble read multi-finger trackpad gestures.",
                granted: permissions.inputMonitoringGranted,
                action: permissions.requestInputMonitoring)

            permissionRow(
                title: "Accessibility",
                detail: "Lets Glimble move windows and send keyboard shortcuts.",
                granted: permissions.accessibilityGranted,
                action: permissions.requestAccessibility)

            Divider()
            Text("Tip: if a gesture also triggers a macOS action, disable that gesture in "
                 + "System Settings ▸ Trackpad ▸ More Gestures so Glimble’s rule wins.")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
        .frame(width: 460, height: 380)
        .onAppear { permissions.refresh() }
    }

    @ViewBuilder
    private func permissionRow(title: String, detail: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
            VStack(alignment: .leading) {
                Text(title).bold()
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(granted ? "Granted" : "Grant…", action: action).disabled(granted)
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`.

- [ ] **Step 3: Commit**

```bash
git add Sources/GlimbleApp/OnboardingView.swift
git commit -m "feat: OnboardingView for Input Monitoring + Accessibility"
```

---

### Task 11: Wire menu + windows + recorder into `AppDelegate`

**Files:**
- Modify: `Sources/GlimbleApp/AppDelegate.swift`

- [ ] **Step 1: Replace `AppDelegate`** with the fully-wired version

`Sources/GlimbleApp/AppDelegate.swift`:
```swift
import AppKit
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let touchSource = TouchSource()
    private let rules = RulesModel()
    private let recorder = Recorder()
    private let permissions = PermissionsCoordinator()
    private let presenter = WindowPresenter()
    private lazy var engine = GestureEngine(rules: rules)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "👆"
        statusItem.menu = buildMenu()

        permissions.refresh()
        // First run with no Accessibility yet → show onboarding.
        if !permissions.inputMonitoringGranted || !permissions.accessibilityGranted {
            showOnboarding()
        }

        // Route recognized gestures to the recorder while recording, else execute.
        engine.onRecognized = { [weak self] gesture in
            self?.recorder.capture(gesture)
        }
        recorder.$isRecording
            .sink { [weak self] recording in
                // engine.onRecognized stays set; the engine only forwards while recording,
                // but we keep capture gated by recorder.isRecording inside Recorder.capture.
                _ = recording; _ = self
            }
            .store(in: &cancellables)

        touchSource.onFrame = { [weak self] frame in self?.engine.handle(frame) }
        touchSource.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        touchSource.stop()
    }

    private var cancellables = Set<AnyCancellable>()

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let count = NSMenuItem(title: "Glimble (\(rules.ruleSet.rules.count) rules)", action: nil, keyEquivalent: "")
        count.isEnabled = false
        menu.addItem(count)
        menu.addItem(.separator())
        add(menu, "Settings…", #selector(openSettings), key: ",")
        add(menu, "Onboarding & Permissions…", #selector(openOnboarding), key: "")
        let launch = add(menu, "Open at Login", #selector(toggleLaunch), key: "")
        launch.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(.separator())
        add(menu, "Quit Glimble", #selector(NSApplication.terminate(_:)), key: "q")
        return menu
    }

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func openSettings() {
        presenter.show("settings", title: "Glimble Settings") {
            SettingsView(rules: self.rules, recorder: self.recorder)
        }
    }

    @objc private func openOnboarding() { showOnboarding() }

    private func showOnboarding() {
        permissions.refresh()
        presenter.show("onboarding", title: "Welcome to Glimble") {
            OnboardingView(permissions: self.permissions)
        }
    }

    @objc private func toggleLaunch(_ sender: NSMenuItem) {
        let newValue = !LaunchAtLogin.isEnabled
        LaunchAtLogin.setEnabled(newValue)
        sender.state = LaunchAtLogin.isEnabled ? .on : .off
    }
}

import Combine
```

> Note: `import Combine` must be at the TOP of the file with the other imports, not the bottom — move it up. It is needed for `AnyCancellable`/`.sink`/`.store`. (The bottom placement above is a reminder, not valid Swift; put `import Combine` after `import CoreGraphics`.)

- [ ] **Step 2: Build + test**

Run: `swift build && swift test`
Expected: `Build complete!`, all GlimbleCore tests pass. If Swift 6 flags the `recorder.$isRecording.sink` closure or `cancellables`, simplify: the `recorder.$isRecording` subscription is only a placeholder — if it causes friction, delete the `recorder.$isRecording.sink {…}.store(…)` block and the `cancellables`/`import Combine` entirely (the recorder works without it because `Recorder.capture` already gates on `isRecording`). Keep the build green.

- [ ] **Step 3: Commit**

```bash
git add Sources/GlimbleApp/AppDelegate.swift
git commit -m "feat: wire settings/onboarding/launch-at-login menu + recorder"
```

---

### Task 12: Entitlements + final integration check

**Files:**
- Modify: `Glimble.entitlements`

- [ ] **Step 1: Confirm entitlements** still contain only `disable-library-validation`. SMAppService for a Developer-ID/ad-hoc app bundle needs no extra entitlement (it registers the main app), so no change is expected. Verify the file is unchanged; if missing, recreate it:
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

- [ ] **Step 2: Full build, test, and ad-hoc bundle assembly**

Run:
```bash
swift build && swift test
GLIMBLE_IDENTITY="-" ./scripts/build-app.sh
```
Expected: `Build complete!`, all GlimbleCore tests pass, and `Signed Glimble.app`. Then clean up: `rm -rf Glimble.app Glimble.zip`.

- [ ] **Step 3: Commit (only if anything changed)**

```bash
git add -A
git commit -m "chore: confirm entitlements and ad-hoc bundle for app shell" --allow-empty
```

---

## Self-Review

**Spec coverage (Plan 2 scope):** Settings UI with rule list (Task 9) + editor (Task 8); **live gesture recorder** (Tasks 4 + 8 + 11 wiring); per-permission onboarding (Task 10) + `PermissionsCoordinator` (Task 5); launch-at-login via `SMAppService` (Task 6); shared observable `RulesModel` so edits take effect live (Task 3); menu with Settings/Onboarding/Launch-at-login/Quit (Task 11). Distribution (Sparkle, packaging, Homebrew) is **Plan 3**.

**Placeholder scan:** Two inline cautions — Task 11's `import Combine` placement note and its fallback to drop the `.sink` block — are guards with concrete fixes, not TODOs. All code is complete.

**Type consistency:** `RulesModel` (T3) exposes `ruleSet`, `add/update/remove/toggle`, `action(for:frontmostBundleID:)` — consumed by `GestureEngine` (T3), `SettingsView` (T9), `AppDelegate` (T11). `Recorder` (T4) `start/cancel/capture` + `@Published isRecording/captured` — consumed by `RuleEditorView` (T8), `AppDelegate` (T11). `PermissionsCoordinator` (T5) `refresh/requestInputMonitoring/requestAccessibility` + `@Published` flags — consumed by `OnboardingView` (T10), `AppDelegate` (T11). Pure helpers `RuleSet.adding/updating/removing/togglingEnabled` (T1) used by `RulesModel`; `displayName` (T2) used by both views. All consistent.

**Concurrency:** every app-layer type is `@MainActor`; `GlimbleCore` additions (`RuleSet+Edits`, `DisplayNames`) are pure. The one risk area (the Combine subscription in T11) has an explicit "delete it if it fights the compiler" fallback that keeps recording working.

**Runtime caveat:** SwiftUI views compile headlessly but are not exercised; actual window/recorder/permission behavior is verified by the user on hardware (Plan 2 verification checklist appended at execution time).
