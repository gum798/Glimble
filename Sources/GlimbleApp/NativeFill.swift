import AppKit
import ApplicationServices

/// Invokes macOS's native "Fill" tiling on the frontmost app's window by pressing its
/// Window-menu "Fill" item through the Accessibility API — so the OS performs the resize
/// (its own margins / multi-display rules) rather than Glimble forcing a frame.
///
/// Best-effort: throws if the app exposes no such item (non-AppKit menus, older apps, disabled
/// item). The caller then falls back to an explicit frame fill.
@MainActor
enum NativeFill {
    enum FillError: Error { case noMenuBar, notFound, disabled, pressFailed(AXError) }

    /// Press the frontmost app's native "Fill" menu item without opening the menu.
    static func fill(app axApp: AXUIElement) throws {
        guard let menuBar = element(axApp, kAXMenuBarAttribute as CFString) else {
            throw FillError.noMenuBar
        }
        guard let windowMenu = windowMenu(in: menuBar) else { throw FillError.notFound }
        guard let fillItem = findFillItem(in: windowMenu) else { throw FillError.notFound }
        if boolAttr(fillItem, kAXEnabledAttribute as CFString) == false { throw FillError.disabled }
        let err = AXUIElementPerformAction(fillItem, kAXPressAction as CFString)
        guard err == .success else { throw FillError.pressFailed(err) }
    }

    // MARK: - Menu navigation

    /// The `AXMenu` owned by the menu bar's "Window" item.
    private static func windowMenu(in menuBar: AXUIElement) -> AXUIElement? {
        let titles: Set<String> = ["Window", "윈도우", "ウインドウ", "Fenster", "Fenêtre",
                                    "Ventana", "Finestra", "窗口", "Janela"]
        let items = children(menuBar)
        // Prefer the item titled like "Window"; else the conventional 2nd-from-last (…, Window, Help).
        let windowItem = items.first { titles.contains(string($0, kAXTitleAttribute as CFString) ?? "") }
            ?? (items.count >= 2 ? items[items.count - 2] : nil)
        guard let windowItem else { return nil }
        return children(windowItem).first(where: isMenu)
    }

    /// Recursively find "Fill" (top-level in Sequoia/Tahoe, but search submenus to be safe).
    private static func findFillItem(in menu: AXUIElement) -> AXUIElement? {
        for item in children(menu) {
            if matchesFill(item) { return item }
            if let submenu = children(item).first(where: isMenu),
               let hit = findFillItem(in: submenu) {
                return hit
            }
        }
        return nil
    }

    /// Match "Fill" locale-independently via its Control-F shortcut metadata, falling back to title.
    private static func matchesFill(_ item: AXUIElement) -> Bool {
        // Cmd-modifiers mask: bit2(4)=Control present, bit3(8)=Command ABSENT (inverted). No Fn bit,
        // so Fill's real Fn-Control-F reads here as plain Control-F.
        if let mods = intAttr(item, "AXMenuItemCmdModifiers" as CFString) {
            let controlPresent = (mods & 0x4) != 0
            let commandAbsent = (mods & 0x8) != 0
            let isF = string(item, "AXMenuItemCmdChar" as CFString)?.lowercased() == "f"
                || intAttr(item, "AXMenuItemCmdVirtualKey" as CFString) == 0x03   // kVK_ANSI_F
            if isF && controlPresent && commandAbsent { return true }
        }
        let titles: Set<String> = ["Fill", "화면 채우기", "フィル", "Füllen", "Remplir",
                                    "Rellenar", "Riempi", "填充", "Preencher"]
        return titles.contains(string(item, kAXTitleAttribute as CFString) ?? "")
    }

    // MARK: - AX helpers

    private static func isMenu(_ el: AXUIElement) -> Bool {
        (string(el, kAXRoleAttribute as CFString) ?? "") == (kAXMenuRole as String)
    }

    private static func element(_ el: AXUIElement, _ attr: CFString) -> AXUIElement? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr, &ref) == .success,
              let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
        return (ref as! AXUIElement)
    }

    private static func children(_ el: AXUIElement) -> [AXUIElement] {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &ref) == .success,
              let arr = ref as? [AXUIElement] else { return [] }
        return arr
    }

    private static func string(_ el: AXUIElement, _ attr: CFString) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr, &ref) == .success else { return nil }
        return ref as? String
    }

    private static func intAttr(_ el: AXUIElement, _ attr: CFString) -> Int? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr, &ref) == .success else { return nil }
        return (ref as? NSNumber)?.intValue
    }

    private static func boolAttr(_ el: AXUIElement, _ attr: CFString) -> Bool? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr, &ref) == .success else { return nil }
        return (ref as? NSNumber)?.boolValue
    }
}
