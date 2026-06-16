import SwiftUI
import AppKit
import GlimbleCore

/// Edit (or create) one rule.
///
/// Layout — "hero-record": a large, inviting record panel anchors the top of the sheet. It is
/// dashed-and-empty until a gesture is captured, then fills with the gesture's SF Symbol + name and
/// a finger-count subtitle. The panel is unmistakably the primary affordance: tapping it calls
/// `recorder.start()` and the user performs a real trackpad gesture. While armed it shows a distinct
/// orange "Listening…" treatment to separate waiting from captured. The action and scope live in
/// calm, Shortcuts-style cards beneath, each with its own contextual control; app pickers show real
/// app icons + names. A sticky footer carries a live status cue plus Cancel / Save.
struct RuleEditorView: View {
    @ObservedObject var recorder: Recorder
    let existing: Rule?
    let onSave: (Rule) -> Void
    let onCancel: () -> Void

    @State private var trigger: RecognizedGesture?
    @State private var actionKind: ActionKind = .window
    @State private var snapPosition: SnapPosition = .maximize
    @State private var shortcutKeyCode: UInt16?
    @State private var shortcutModifiers: [KeyModifier] = []
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

        var symbol: String {
            switch self {
            case .window: return "macwindow.on.rectangle"
            case .keyboardShortcut: return "command"
            case .shell: return "terminal"
            case .appleScript: return "applescript"
            case .runShortcut: return "square.stack.3d.up"
            case .launchApp: return "app.dashed"
            }
        }

        var tint: Color {
            switch self {
            case .window: return .blue
            case .keyboardShortcut: return .purple
            case .shell: return .green
            case .appleScript: return .orange
            case .runShortcut: return .pink
            case .launchApp: return .teal
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider()

            ScrollView {
                VStack(spacing: 18) {
                    heroPanel
                    actionCard
                    scopeCard
                }
                .padding(20)
            }
            .frame(maxHeight: 540)

            Divider()
            footer
        }
        .frame(width: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: loadExisting)
        .onDisappear { recorder.cancel() }   // never leave the shared recorder armed after exit
        .onChange(of: recorder.captured) { _, newValue in
            if let g = newValue { trigger = g }
        }
    }

    // MARK: - Title bar

    private var titleBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.accentColor.gradient)
                    .frame(width: 30, height: 30)
                Image(systemName: existing == nil ? "plus" : "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(existing == nil ? "New Rule" : "Edit Rule")
                    .font(.headline)
                Text("Map a trackpad gesture to an action")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Hero record panel

    private var heroPanel: some View {
        Button(action: startRecording) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(heroFill)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(heroStroke, style: heroStrokeStyle)

                heroBody
                    .padding(.horizontal, 24)
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 196)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .animation(.easeInOut(duration: 0.2), value: recorder.isRecording)
            .animation(.easeInOut(duration: 0.2), value: trigger)
        }
        .buttonStyle(.plain)
        .disabled(recorder.isRecording)
        .accessibilityLabel(trigger == nil ? "Record gesture" : "Re-record gesture")
        .accessibilityHint("Performs a trackpad gesture to set this rule's trigger")
    }

    @ViewBuilder
    private var heroBody: some View {
        if recorder.isRecording {
            VStack(spacing: 14) {
                RecordingPulse()
                VStack(spacing: 4) {
                    Text("Listening…")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("Swipe, tap, or pinch on the trackpad now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } else if let trigger {
            VStack(spacing: 12) {
                Image(systemName: GestureGlyph.symbol(for: trigger))
                    .font(.system(size: 44, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                VStack(spacing: 4) {
                    Text(trigger.displayName)
                        .font(.title3.weight(.semibold))
                    Text(GestureGlyph.subtitle(for: trigger))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("Recorded — tap to record again", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                        .padding(.top, 2)
                }
            }
        } else {
            VStack(spacing: 14) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 42, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                VStack(spacing: 4) {
                    Text("Record a Gesture")
                        .font(.title3.weight(.semibold))
                    Text("Tap here, then perform a trackpad gesture")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var heroFill: AnyShapeStyle {
        if recorder.isRecording { return AnyShapeStyle(Color.orange.opacity(0.10)) }
        if trigger != nil { return AnyShapeStyle(Color.accentColor.opacity(0.06)) }
        return AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
    }

    private var heroStroke: AnyShapeStyle {
        if recorder.isRecording { return AnyShapeStyle(Color.orange.opacity(0.6)) }
        if trigger != nil { return AnyShapeStyle(Color.accentColor.opacity(0.55)) }
        return AnyShapeStyle(Color.secondary.opacity(0.3))
    }

    private var heroStrokeStyle: StrokeStyle {
        // Dashed while empty or actively listening; solid once a gesture is captured.
        if trigger != nil && !recorder.isRecording {
            return StrokeStyle(lineWidth: 1.5)
        }
        return StrokeStyle(lineWidth: 1.5, dash: [7, 5])
    }

    private func startRecording() {
        guard !recorder.isRecording else { return }
        recorder.start()
    }

    // MARK: - Action card

    private var actionCard: some View {
        Card(icon: "bolt.fill", iconTint: .orange, title: "Action") {
            VStack(spacing: 0) {
                Row(label: "Type") {
                    Menu {
                        ForEach(ActionKind.allCases) { kind in
                            Button {
                                actionKind = kind
                            } label: {
                                Label(kind.rawValue, systemImage: kind.symbol)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: actionKind.symbol)
                                .foregroundStyle(actionKind.tint)
                            Text(actionKind.rawValue)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                Divider().padding(.leading, 2)

                actionFields
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private var actionFields: some View {
        switch actionKind {
        case .window:
            Row(label: "Position") {
                Picker("", selection: $snapPosition) {
                    ForEach(SnapPosition.allCases, id: \.self) { pos in
                        Label(pos.displayName, systemImage: SnapGlyph.symbol(for: pos)).tag(pos)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
        case .keyboardShortcut:
            Row(label: "Shortcut") {
                ShortcutField(keyCode: $shortcutKeyCode, modifiers: $shortcutModifiers)
            }
        case .shell:
            FieldRow(label: "Command",
                     placeholder: "/usr/bin/say hello",
                     monospaced: true,
                     text: $textValue)
        case .appleScript:
            FieldRow(label: "Script",
                     placeholder: "tell application \"Finder\" to activate",
                     monospaced: true,
                     text: $textValue)
        case .runShortcut:
            FieldRow(label: "Shortcut name",
                     placeholder: "My Shortcut",
                     monospaced: false,
                     text: $textValue)
        case .launchApp:
            Row(label: "Application") {
                AppPicker(selection: $launchBundleID, placeholder: "Choose an app…")
            }
        }
    }

    // MARK: - Scope card

    private var scopeCard: some View {
        Card(icon: "scope", iconTint: .blue, title: "Applies To") {
            VStack(alignment: .leading, spacing: 8) {
                Row(label: "Scope") {
                    AppPicker(selection: $scopeBundleID,
                              placeholder: "All apps",
                              allowsAllApps: true)
                }
                Text(scopeBundleID.isEmpty
                     ? "Works everywhere."
                     : "Only works when this app is frontmost.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            statusCue
            Spacer(minLength: 12)
            Button("Cancel", role: .cancel) { onCancel() }
                .keyboardShortcut(.cancelAction)
            Button {
                save()
            } label: {
                Text(existing == nil ? "Add Rule" : "Save Changes")
                    .frame(minWidth: 96)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(trigger == nil || !actionIsValid)
        }
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    /// A live cue that explains why Save is disabled (or that the rule is ready).
    @ViewBuilder
    private var statusCue: some View {
        let ready = trigger != nil && actionIsValid
        HStack(spacing: 6) {
            Image(systemName: ready ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(ready ? AnyShapeStyle(Color.green) : AnyShapeStyle(.secondary))
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private var statusText: String {
        if trigger == nil { return "Record a gesture to continue" }
        if !actionIsValid { return "Finish configuring the action" }
        return "Ready to save"
    }

    // MARK: - Validation

    private var actionIsValid: Bool {
        switch actionKind {
        case .window: return true
        case .keyboardShortcut: return shortcutKeyCode != nil
        case .shell, .appleScript, .runShortcut: return !textValue.isEmpty
        case .launchApp: return !launchBundleID.isEmpty
        }
    }

    // MARK: - Persistence (unchanged logic)

    private func loadExisting() {
        guard let rule = existing else { return }
        trigger = rule.trigger
        if case .app(let b) = rule.scope { scopeBundleID = b }
        switch rule.action {
        case .window(let pos):
            actionKind = .window; snapPosition = pos
        case .keyboardShortcut(let combo):
            actionKind = .keyboardShortcut
            shortcutKeyCode = combo.keyCode
            shortcutModifiers = combo.modifiers
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
            action = .keyboardShortcut(KeyCombo(keyCode: shortcutKeyCode ?? 0, modifiers: shortcutModifiers))
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

// MARK: - Card container

/// A titled card section with a leading SF Symbol chip — the building block beneath the hero.
private struct Card<Content: View>: View {
    let icon: String
    let iconTint: Color
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(iconTint)
                    .frame(width: 18, height: 18)
                    .background(iconTint.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}

/// A single dense row: a leading label and a trailing, right-aligned control.
private struct Row<Control: View>: View {
    let label: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            control
        }
        .padding(.vertical, 7)
        .frame(minHeight: 30)
    }
}

/// A labelled, free-form text field row (shell / AppleScript / shortcut name).
private struct FieldRow: View {
    let label: String
    let placeholder: String
    let monospaced: Bool
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(monospaced ? .body.monospaced() : .body)
        }
        .padding(.vertical, 7)
    }
}

// MARK: - Recording pulse

/// An animated red "recording" dot used while the hero waits for a gesture.
private struct RecordingPulse: View {
    @State private var on = false

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 18, height: 18)
            .scaleEffect(on ? 1.25 : 0.9)
            .opacity(on ? 1 : 0.55)
            .shadow(color: .red.opacity(on ? 0.5 : 0), radius: 6)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                    on = true
                }
            }
    }
}

// MARK: - App picker

/// A `Menu` that lists running regular apps with their icons + names, plus the currently selected
/// app even if it isn't running. Optionally offers an "All apps" (global) choice.
private struct AppPicker: View {
    @Binding var selection: String     // "" == none / all apps
    var placeholder: String
    var allowsAllApps: Bool = false

    private struct AppEntry: Identifiable {
        let id: String     // bundle id
        let name: String
        let icon: NSImage
    }

    var body: some View {
        Menu {
            if allowsAllApps {
                Button { selection = "" } label: { Label("All apps", systemImage: "square.grid.2x2") }
                Divider()
            }
            ForEach(entries) { app in
                Button { selection = app.id } label: {
                    Label {
                        Text(app.name)
                    } icon: {
                        Image(nsImage: app.icon)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let icon = selectedIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                } else if !allowsAllApps {
                    // Never let the launch-app picker look empty/misaligned before a choice.
                    Image(systemName: "questionmark.app.dashed")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }
                Text(selectedTitle)
                    .foregroundStyle(selection.isEmpty && !allowsAllApps ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: derived

    private var selectedTitle: String {
        if selection.isEmpty { return allowsAllApps ? "All apps" : placeholder }
        return AppDirectory.name(for: selection)
    }

    private var selectedIcon: NSImage? {
        guard !selection.isEmpty else { return nil }
        return AppDirectory.icon(for: selection)
    }

    /// Running regular apps plus the current selection (so a saved value stays selectable),
    /// sorted by display name.
    private var entries: [AppEntry] {
        var seen = Set<String>()
        var ids: [String] = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.bundleIdentifier }
        if !selection.isEmpty { ids.append(selection) }
        let unique = ids.filter { seen.insert($0).inserted }
        return unique
            .map { AppEntry(id: $0, name: AppDirectory.name(for: $0), icon: AppDirectory.icon(for: $0)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

/// Resolves bundle ids to friendly names + icons via NSWorkspace.
private enum AppDirectory {
    static func name(for bundleID: String) -> String {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }),
           let n = app.localizedName {
            return n
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }

    static func icon(for bundleID: String) -> NSImage {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }),
           let icon = app.icon {
            return icon
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }
}

// MARK: - Glyph helpers

/// SF Symbol + a finger-count subtitle for a recognized gesture
/// (tap / multi-tap / swipe arrows / pinch magnifier).
private enum GestureGlyph {
    static func symbol(for g: RecognizedGesture) -> String {
        switch g {
        case .tap: return "hand.tap"
        case .doubleTap: return "hand.tap.fill"
        case .tripleTap: return "hand.tap.fill"
        case .pinch(_, let zoom): return zoom == .zoomIn ? "plus.magnifyingglass" : "minus.magnifyingglass"
        case .swipe(_, let dir):
            switch dir {
            case .left: return "arrow.left"
            case .right: return "arrow.right"
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            }
        }
    }

    /// A concise "N fingers · …" confirmation of exactly what was captured.
    static func subtitle(for g: RecognizedGesture) -> String {
        switch g {
        case .tap(let f): return "\(fingerLabel(f)) · tap"
        case .doubleTap(let f): return "\(fingerLabel(f)) · double tap"
        case .tripleTap(let f): return "\(fingerLabel(f)) · triple tap"
        case .swipe(let f, let dir): return "\(fingerLabel(f)) · swipe \(dir.rawValue)"
        case .pinch(let f, let zoom): return "\(fingerLabel(f)) · zoom \(zoom.rawValue)"
        }
    }

    private static func fingerLabel(_ count: Int) -> String {
        "\(count) finger\(count == 1 ? "" : "s")"
    }
}

/// SF Symbol for a window snap position.
private enum SnapGlyph {
    static func symbol(for pos: SnapPosition) -> String {
        switch pos {
        case .left: return "rectangle.lefthalf.filled"
        case .right: return "rectangle.righthalf.filled"
        case .top: return "rectangle.tophalf.filled"
        case .bottom: return "rectangle.bottomhalf.filled"
        case .topLeft: return "rectangle.inset.topleft.filled"
        case .topRight: return "rectangle.inset.topright.filled"
        case .bottomLeft: return "rectangle.inset.bottomleft.filled"
        case .bottomRight: return "rectangle.inset.bottomright.filled"
        case .maximize: return "arrow.up.left.and.arrow.down.right"
        case .center: return "rectangle.center.inset.filled"
        case .fill: return "rectangle.fill"
        case .minimize: return "dock.arrow.down.rectangle"
        }
    }
}
