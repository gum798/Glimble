import SwiftUI

struct GeneralTab: View {
    @ObservedObject var settings: AppSettings
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section {
                Toggle("Open Glimble at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in LaunchAtLogin.setEnabled(on) }
            }
            Section("Double-tap") {
                HStack {
                    Slider(value: $settings.doubleTapWindow, in: 0.15...0.6)
                    Text("\(Int(settings.doubleTapWindow * 1000)) ms")
                        .monospacedDigit().foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
                }
                Text("Maximum time between the two taps of a double-tap.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
