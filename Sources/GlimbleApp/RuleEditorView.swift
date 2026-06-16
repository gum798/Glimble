import SwiftUI
import AppKit
import GlimbleCore

/// Edit (or create) one rule. The trigger is set by tapping "Record" and performing the gesture;
/// the action picker exposes every `GlimbleAction` kind.
struct RuleEditorView: View {
    @ObservedObject var recorder: Recorder
    let existing: Rule?
    let onSave: (Rule) -> Void
    let onCancel: () -> Void

    @State private var trigger: RecognizedGesture?
    @State private var actionKind: ActionKind = .window
    @State private var snapPosition: SnapPosition = .maximize
    @State private var keyCodeText = ""
    @State private var modCommand = false
    @State private var modOption = false
    @State private var modControl = false
    @State private var modShift = false
    @State private var textValue = ""           // shell / appleScript / runShortcut
    @State private var launchBundleID = ""
    @State private var scopeBundleID = ""        // "" = global

    enum ActionKind: String, CaseIterable, Identifiable {
        case window = "Snap / move window"
        case keyboardShortcut = "Keyboard shortcut"
        case shell = "Run shell command"
        case appleScript = "Run AppleScript"
        case runShortcut = "Run Shortcut"
        case launchApp = "Launch app"
        var id: String { rawValue }
    }

    var body: some View {
        Form {
            Section("Trigger") {
                HStack {
                    Text(trigger?.displayName ?? "No gesture yet")
                        .foregroundStyle(trigger == nil ? .secondary : .primary)
                    Spacer()
                    Button(recorder.isRecording ? "Perform gesture…" : "Record") { recorder.start() }
                        .disabled(recorder.isRecording)
                }
            }
            Section("Action") {
                Picker("Do", selection: $actionKind) {
                    ForEach(ActionKind.allCases) { Text($0.rawValue).tag($0) }
                }
                actionFields
            }
            Section("Applies to") {
                Picker("Scope", selection: $scopeBundleID) {
                    Text("All apps").tag("")
                    ForEach(scopeChoices(), id: \.self) { Text($0).tag($0) }
                }
            }
            HStack {
                Button("Cancel", role: .cancel) { onCancel() }
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trigger == nil || !actionIsValid)
            }
        }
        .padding()
        .frame(width: 460)
        .onAppear(perform: loadExisting)
        .onDisappear { recorder.cancel() }   // never leave the shared recorder armed after exit
        .onChange(of: recorder.captured) { _, newValue in
            if let g = newValue { trigger = g }
        }
    }

    @ViewBuilder
    private var actionFields: some View {
        switch actionKind {
        case .window:
            Picker("Position", selection: $snapPosition) {
                ForEach(SnapPosition.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
        case .keyboardShortcut:
            TextField("Key code", text: $keyCodeText)
            Text("macOS virtual key code (123=←, 124=→, 125=↓, 126=↑, 36=Return, 49=Space)")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Toggle("⌘", isOn: $modCommand)
                Toggle("⌥", isOn: $modOption)
                Toggle("⌃", isOn: $modControl)
                Toggle("⇧", isOn: $modShift)
            }
        case .shell:
            TextField("Command", text: $textValue)
        case .appleScript:
            TextField("AppleScript", text: $textValue)
        case .runShortcut:
            TextField("Shortcut name", text: $textValue)
        case .launchApp:
            Picker("App", selection: $launchBundleID) {
                Text("Choose…").tag("")
                ForEach(appChoices(), id: \.self) { Text($0).tag($0) }
            }
        }
    }

    private var actionIsValid: Bool {
        switch actionKind {
        case .window: return true
        case .keyboardShortcut: return UInt16(keyCodeText) != nil
        case .shell, .appleScript, .runShortcut: return !textValue.isEmpty
        case .launchApp: return !launchBundleID.isEmpty
        }
    }

    private func runningApps() -> [String] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.bundleIdentifier }
            .sorted()
    }

    /// Running apps plus the selected launch target, so a saved value stays selectable.
    private func appChoices() -> [String] {
        var apps = runningApps()
        if !launchBundleID.isEmpty && !apps.contains(launchBundleID) { apps.insert(launchBundleID, at: 0) }
        return apps
    }

    /// Running apps plus the selected scope, so an app-scoped rule for a non-running app shows.
    private func scopeChoices() -> [String] {
        var apps = runningApps()
        if !scopeBundleID.isEmpty && !apps.contains(scopeBundleID) { apps.insert(scopeBundleID, at: 0) }
        return apps
    }

    private func loadExisting() {
        guard let rule = existing else { return }
        trigger = rule.trigger
        if case .app(let b) = rule.scope { scopeBundleID = b }
        switch rule.action {
        case .window(let pos):
            actionKind = .window; snapPosition = pos
        case .keyboardShortcut(let combo):
            actionKind = .keyboardShortcut
            keyCodeText = String(combo.keyCode)
            modCommand = combo.modifiers.contains(.command)
            modOption = combo.modifiers.contains(.option)
            modControl = combo.modifiers.contains(.control)
            modShift = combo.modifiers.contains(.shift)
        case .shell(let c):
            actionKind = .shell; textValue = c
        case .appleScript(let s):
            actionKind = .appleScript; textValue = s
        case .runShortcut(let n):
            actionKind = .runShortcut; textValue = n
        case .launchApp(let b):
            actionKind = .launchApp; launchBundleID = b
        }
    }

    private func save() {
        guard let trigger else { return }
        let action: GlimbleAction
        switch actionKind {
        case .window:
            action = .window(snapPosition)
        case .keyboardShortcut:
            var mods: [KeyModifier] = []
            if modCommand { mods.append(.command) }
            if modOption { mods.append(.option) }
            if modControl { mods.append(.control) }
            if modShift { mods.append(.shift) }
            action = .keyboardShortcut(KeyCombo(keyCode: UInt16(keyCodeText) ?? 0, modifiers: mods))
        case .shell:
            action = .shell(textValue)
        case .appleScript:
            action = .appleScript(textValue)
        case .runShortcut:
            action = .runShortcut(textValue)
        case .launchApp:
            action = .launchApp(bundleID: launchBundleID)
        }
        let scope: RuleScope = scopeBundleID.isEmpty ? .global : .app(bundleID: scopeBundleID)
        let rule = Rule(id: existing?.id ?? UUID(), scope: scope, trigger: trigger,
                        action: action, enabled: existing?.enabled ?? true)
        onSave(rule)
    }
}
