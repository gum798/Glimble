import SwiftUI

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.tap.fill").font(.system(size: 52)).foregroundStyle(.tint)
            Text("Glimble").font(.title).bold()
            Text("Version \(version)").foregroundStyle(.secondary)
            Text("Map trackpad gestures to actions — snap windows, run shortcuts and scripts.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Link("github.com/gum798/Glimble", destination: URL(string: "https://github.com/gum798/Glimble")!)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
    }

    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev"
    }
}
