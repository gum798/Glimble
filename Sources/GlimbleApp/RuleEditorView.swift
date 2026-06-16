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
