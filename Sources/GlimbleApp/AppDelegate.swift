import AppKit
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var countItem: NSMenuItem?
    private var launchItem: NSMenuItem?
    private let touchSource = TouchSource()
    private let rules = RulesModel()
    private let recorder = Recorder()
    private let settings = AppSettings()
    private let permissions = PermissionsCoordinator()
    private let presenter = WindowPresenter()
    private lazy var engine = GestureEngine(rules: rules, settings: settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let icon = NSImage(systemSymbolName: "hand.tap.fill", accessibilityDescription: "Glimble") {
            icon.isTemplate = true   // single color, adapts to light/dark menu bar
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "Glimble"
        }
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
        engine.isRecordingActive = { [weak recorder] in recorder?.isRecording ?? false }

        touchSource.onFrame = { [weak self] frame in self?.engine.handle(frame) }
        touchSource.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        touchSource.stop()
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        let count = NSMenuItem(title: ruleCountTitle(), action: nil, keyEquivalent: "")
        count.isEnabled = false
        menu.addItem(count)
        countItem = count
        menu.addItem(.separator())
        add(menu, "Settings…", #selector(openSettings), key: ",")
        add(menu, "Onboarding & Permissions…", #selector(openOnboarding), key: "")
        let launch = add(menu, "Open at Login", #selector(toggleLaunch), key: "")
        launch.state = LaunchAtLogin.isEnabled ? .on : .off
        launchItem = launch
        menu.addItem(.separator())
        // Quit's target stays nil so it routes up the responder chain to NSApp.terminate.
        // (Going through `add` would set target = self, and AppDelegate doesn't implement
        // terminate(_:), so AppKit would auto-disable the item — that was the bug.)
        menu.addItem(NSMenuItem(title: "Quit Glimble",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func ruleCountTitle() -> String { "Glimble (\(rules.ruleSet.rules.count) rules)" }

    /// Refresh the live bits (rule count, login state) each time the menu opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        countItem?.title = ruleCountTitle()
        launchItem?.state = LaunchAtLogin.isEnabled ? .on : .off
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
            SettingsView(rules: self.rules, recorder: self.recorder, settings: self.settings)
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
