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
