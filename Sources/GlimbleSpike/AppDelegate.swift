import AppKit
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let touchReader = TouchReader()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "👆 –"

        let menu = NSMenu()
        let quit = NSMenuItem(title: "Quit Glimble Spike",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu

        // Input Monitoring (kTCCServiceListenEvent): force the TCC prompt if not yet granted.
        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
        }

        touchReader.onCount = { [weak self] count in
            self?.statusItem.button?.title = "👆 \(count)"
        }
        touchReader.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        touchReader.stop()
    }
}
