import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let touchSource = TouchSource()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "👆 –"

        let menu = NSMenu()
        let snapLeft  = NSMenuItem(title: "Snap Left",  action: #selector(snapLeft),  keyEquivalent: "")
        let snapRight = NSMenuItem(title: "Snap Right", action: #selector(snapRight), keyEquivalent: "")
        let maximize  = NSMenuItem(title: "Maximize",   action: #selector(maximize),  keyEquivalent: "")
        for item in [snapLeft, snapRight, maximize] {
            item.target = self          // accessory apps aren't reliably in the responder chain
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Glimble Spike",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu

        // Input Monitoring (kTCCServiceListenEvent): force the TCC prompt if not yet granted.
        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
        }

        // Accessibility (kTCCServiceAccessibility): needed to set window position/size.
        // kAXTrustedCheckOptionPrompt == "AXTrustedCheckOptionPrompt"; using the string
        // literal avoids referencing the non-concurrency-safe global CFString under Swift 6.
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)

        touchSource.onFrame = { [weak self] frame in
            self?.statusItem.button?.title = "👆 \(frame.fingerCount)"
        }
        touchSource.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        touchSource.stop()
    }

    @objc private func snapLeft()  { try? WindowSnapper.snapFocusedWindow(to: .left) }
    @objc private func snapRight() { try? WindowSnapper.snapFocusedWindow(to: .right) }
    @objc private func maximize()  { try? WindowSnapper.snapFocusedWindow(to: .maximize) }
}
