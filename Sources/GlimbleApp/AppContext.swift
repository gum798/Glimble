import AppKit

/// Provides the frontmost application's bundle identifier for rule scoping.
@MainActor
enum AppContext {
    /// Bundle id of the frontmost (active) app, or nil if unavailable.
    static var frontmostBundleID: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
