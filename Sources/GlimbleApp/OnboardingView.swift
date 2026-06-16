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
