import SwiftUI
import AppKit
import UniformTypeIdentifiers
import GlimbleCore

struct RulesTab: View {
    @ObservedObject var rules: RulesModel
    @ObservedObject var recorder: Recorder

    @State private var search = ""
    @State private var editing: Rule?
    @State private var showingEditor = false
    @State private var showResetConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if rules.ruleSet.rules.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(groups, id: \.title) { group in
                        Section(group.title) {
                            ForEach(group.rules) { row($0) }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .confirmationDialog("Reset all rules to the defaults?",
                            isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { rules.resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        }
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

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search", text: $search).textFieldStyle(.plain)
            Spacer()
            Menu {
                Button("Reset to Defaults…") { showResetConfirm = true }
                Divider()
                Button("Import…") { importRules() }
                Button("Export…") { exportRules() }
            } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).fixedSize()
            Button { editing = nil; showingEditor = true } label: {
                Label("Add Rule", systemImage: "plus")
            }
        }
        .padding(10)
    }

    private func row(_ rule: Rule) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(get: { rule.enabled }, set: { _ in rules.toggle(id: rule.id) }))
                .labelsHidden().toggleStyle(.switch).controlSize(.small)
            Image(systemName: gestureSymbol(rule.trigger))
                .frame(width: 20).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text((rule.modifiers.symbols.isEmpty ? "" : rule.modifiers.symbols + "  ") + rule.trigger.displayName)
                Text(rule.action.displayName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { editing = rule; showingEditor = true } label: { Image(systemName: "pencil") }
                .buttonStyle(.borderless)
            Button { rules.remove(id: rule.id) } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless).foregroundStyle(.red)
        }
        .padding(.vertical, 3)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.tap").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("No rules yet").font(.headline)
            Text("Add a rule and record a trackpad gesture to map it to an action.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { editing = nil; showingEditor = true } label: { Label("Add Rule", systemImage: "plus") }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
    }

    // MARK: data

    private var filtered: [Rule] {
        guard !search.isEmpty else { return rules.ruleSet.rules }
        let q = search.lowercased()
        return rules.ruleSet.rules.filter {
            $0.trigger.displayName.lowercased().contains(q) || $0.action.displayName.lowercased().contains(q)
        }
    }

    private var groups: [(title: String, rules: [Rule])] {
        let byScope = Dictionary(grouping: filtered) { (r: Rule) -> String in
            if case .app(let b) = r.scope { return b }
            return ""
        }
        var result: [(String, [Rule])] = []
        if let g = byScope[""], !g.isEmpty { result.append(("Global", g)) }
        for key in byScope.keys.filter({ !$0.isEmpty }).sorted() {
            result.append((appName(key), byScope[key] ?? []))
        }
        return result
    }

    private func appName(_ bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private func gestureSymbol(_ g: RecognizedGesture) -> String {
        switch g {
        case .tap: return "hand.tap"
        case .doubleTap: return "hand.tap.fill"
        case .tripleTap: return "hand.tap.fill"
        case .pinch(_, let zoom): return zoom == .zoomIn ? "plus.magnifyingglass" : "minus.magnifyingglass"
        case .rotate(_, let d): return d == .clockwise ? "arrow.clockwise" : "arrow.counterclockwise"
        case .longPress: return "hand.point.up.left.fill"
        case .edgeSwipe: return "arrow.right.to.line"
        case .forceTouch: return "hand.point.up.left.fill"
        case .swipe(_, let dir):
            switch dir {
            case .left: return "arrow.left"; case .right: return "arrow.right"
            case .up: return "arrow.up"; case .down: return "arrow.down"
            }
        }
    }

    // MARK: import / export

    private func exportRules() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "glimble-rules.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? RuleStore(ruleSet: rules.ruleSet).write(to: url)
        }
    }

    private func importRules() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let store = try? RuleStore.load(from: url) {
            rules.replace(with: store.ruleSet)
        }
    }
}
