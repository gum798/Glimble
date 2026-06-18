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
        engine.recordingSink = { [weak recorder] gesture, mods in
            guard let recorder, recorder.isRecording else { return false }
            recorder.capture(gesture, modifiers: mods)
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
        add(menu, "Check for Updates…", #selector(checkForUpdates), key: "")
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

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev"
    }

    private func ruleCountTitle() -> String {
        "Glimble \(appVersion) — \(rules.ruleSet.rules.count) rules"
    }

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

    // MARK: - Updates

    @objc private func checkForUpdates() {
        let current = appVersion
        Task { @MainActor in
            do {
                presentUpdate(try await UpdateChecker.check(currentVersion: current))
            } catch {
                presentUpdateAlert(title: "Couldn’t Check for Updates",
                                   message: error.localizedDescription, buttons: ["OK"])
            }
        }
    }

    private func presentUpdate(_ status: UpdateStatus) {
        switch status {
        case .upToDate(let current):
            presentUpdateAlert(title: "You’re up to date",
                               message: "Glimble \(current) is the latest version.", buttons: ["OK"])
        case .updateAvailable(let latest, let notes, let page):
            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = trimmed.isEmpty
                ? "Glimble \(latest) is available."
                : "Glimble \(latest) is available.\n\n\(trimmed)"
            switch presentUpdateAlert(title: "Update Available", message: message,
                                      buttons: ["Update with Homebrew", "Release Page", "Later"]) {
            case .alertFirstButtonReturn:  runHomebrewUpgrade()
            case .alertSecondButtonReturn: NSWorkspace.shared.open(page)
            default: break
            }
        case .developmentBuild(let latest, let page):
            if presentUpdateAlert(title: "Development Build",
                                  message: "You’re running an unversioned dev build. The latest release is \(latest).",
                                  buttons: ["Release Page", "OK"]) == .alertFirstButtonReturn {
                NSWorkspace.shared.open(page)
            }
        }
    }

    @discardableResult
    private func presentUpdateAlert(title: String, message: String,
                                    buttons: [String]) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        buttons.forEach { alert.addButton(withTitle: $0) }
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal()
    }

    /// Run `brew upgrade --cask glimble` in Terminal via a throwaway `.command` file. Opening a
    /// `.command` runs it in Terminal without needing Automation/AppleEvents permission; the user
    /// sees brew's output and can quit Glimble when told to relaunch.
    private func runHomebrewUpgrade() {
        let script = """
        #!/bin/bash
        echo "Updating Glimble via Homebrew…"
        BREW="$(command -v brew || true)"
        if [ -z "$BREW" ]; then
          for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
            [ -x "$p" ] && BREW="$p" && break
          done
        fi
        if [ -z "$BREW" ]; then
          echo "Homebrew not found. Install it from https://brew.sh or download from the release page."
        else
          "$BREW" upgrade --cask glimble
          echo
          echo "Done. Quit and reopen Glimble to finish updating."
        fi
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("glimble-update.command")
        do {
            try script.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            NSWorkspace.shared.open(url)
        } catch {
            presentUpdateAlert(title: "Couldn’t Start the Update",
                               message: "Run this in Terminal:\n\nbrew upgrade --cask glimble", buttons: ["OK"])
        }
    }
}
