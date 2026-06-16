import SwiftUI

/// The settings window: a tabbed Rules / General / About layout.
struct SettingsView: View {
    @ObservedObject var rules: RulesModel
    @ObservedObject var recorder: Recorder
    @ObservedObject var settings: AppSettings

    var body: some View {
        TabView {
            RulesTab(rules: rules, recorder: recorder)
                .tabItem { Label("Rules", systemImage: "hand.tap") }
            GeneralTab(settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 470)
    }
}
