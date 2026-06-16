import AppKit
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let touchSource = TouchSource()
    private let rules = RulesModel()
    private let recorder = Recorder()
    private let permissions = PermissionsCoordinator()
    private let presenter = WindowPresenter()
    private lazy var engine = GestureEngine(rules: rules)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "👆"
        statusItem.menu = buildMenu()

        // First run (or missing grants) → guide the user through permissions.
        permissions.refresh()
        if !permissions.inputMonitoringGranted || !permissions.accessibilityGranted {
            showOnboarding()
        }

        // Offer each recognized gesture to the recorder FIRST; it consumes the gesture only
        // while the settings editor is actively recording, otherwise the action runs.
        engine.recordingSink = { [weak recorder] gesture in
            guard let recorder, recorder.isRecording else { return false }
            recorder.capture(gesture)
            return true
        }

        touchSource.onFrame = { [weak self] frame in self?.engine.handle(frame) }
        touchSource.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        touchSource.stop()
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let count = NSMenuItem(title: "Glimble (\(rules.ruleSet.rules.count) rules)",
                               action: nil, keyEquivalent: "")
        count.isEnabled = false
        menu.addItem(count)
        menu.addItem(.separator())
        add(menu, "Settings…", #selector(openSettings), key: ",")
        add(menu, "Onboarding & Permissions…", #selector(openOnboarding), key: "")
        let launch = add(menu, "Open at Login", #selector(toggleLaunch), key: "")
        launch.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(.separator())
        add(menu, "Quit Glimble", #selector(NSApplication.terminate(_:)), key: "q")
        return menu
    }

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    // MARK: - Windows

    @objc private func openSettings() {
        presenter.show("settings", title: "Glimble Settings") {
            SettingsView(rules: self.rules, recorder: self.recorder)
        }
    }

    @objc private func openOnboarding() { showOnboarding() }

    private func showOnboarding() {
        permissions.refresh()
        presenter.show("onboarding", title: "Welcome to Glimble") {
            OnboardingView(permissions: self.permissions)
        }
    }

    @objc private func toggleLaunch(_ sender: NSMenuItem) {
        LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        sender.state = LaunchAtLogin.isEnabled ? .on : .off
    }
}
