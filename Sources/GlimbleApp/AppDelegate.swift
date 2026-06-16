import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let touchSource = TouchSource()
    private let engine = GestureEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "👆"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Glimble (\(engine.store.ruleSet.rules.count) rules)",
                                action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Glimble",
                              action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu

        // Permissions: reading touches needs Input Monitoring; actions need Accessibility.
        if !CGPreflightListenEventAccess() { CGRequestListenEventAccess() }
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)

        touchSource.onFrame = { [weak self] frame in self?.engine.handle(frame) }
        touchSource.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        touchSource.stop()
    }
}
