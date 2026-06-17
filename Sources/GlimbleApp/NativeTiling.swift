import AppKit
import ApplicationServices
import GlimbleCore

/// Drives macOS's native window tiling (Window ▸ Move & Resize / Fill) on the frontmost app via
/// the Accessibility menu — so the OS performs the resize (its own margins / multi-display rules)
/// rather than Glimble forcing an explicit frame. Best-effort: returns false when the app exposes
/// no matching item (non-AppKit menus, older apps, disabled), so the caller falls back to a frame.
@MainActor
enum NativeTiling {
    /// Press the native tiling menu item for `position`. Returns true iff a matching, enabled item
    /// was found and pressed.
    static func tile(app axApp: AXUIElement, position: SnapPosition) -> Bool {
        guard let spec = spec(for: position),
              let menuBar = element(axApp, kAXMenuBarAttribute as CFString),
              let windowMenu = windowMenu(in: menuBar),
              let item = findItem(in: windowMenu, spec: spec) else { return false }
        if boolAttr(item, kAXEnabledAttribute as CFString) == false { return false }
        return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
    }

    // MARK: - Per-position match spec

    private struct TileSpec { let titles: Set<String>; let arrowKey: Int? }

    /// Returns nil for positions handled by window buttons (maximize/minimize).
    private static func spec(for position: SnapPosition) -> TileSpec? {
        switch position {
        case .left:        return TileSpec(titles: ["Left", "왼쪽"], arrowKey: 123)            // ←
        case .right:       return TileSpec(titles: ["Right", "오른쪽"], arrowKey: 124)          // →
        case .top:         return TileSpec(titles: ["Top", "상단", "위쪽"], arrowKey: 126)       // ↑
        case .bottom:      return TileSpec(titles: ["Bottom", "하단", "아래쪽"], arrowKey: 125)   // ↓
        case .topLeft:     return TileSpec(titles: ["Top Left", "왼쪽 상단", "왼쪽 위"], arrowKey: nil)
        case .topRight:    return TileSpec(titles: ["Top Right", "오른쪽 상단", "오른쪽 위"], arrowKey: nil)
        case .bottomLeft:  return TileSpec(titles: ["Bottom Left", "왼쪽 하단", "왼쪽 아래"], arrowKey: nil)
        case .bottomRight: return TileSpec(titles: ["Bottom Right", "오른쪽 하단", "오른쪽 아래"], arrowKey: nil)
        case .center:      return TileSpec(titles: ["Center", "중앙 정렬", "가운데"], arrowKey: nil)
        case .fill:        return TileSpec(titles: ["Fill", "채우기", "화면 채우기", "フィル", "Füllen",
                                                    "Remplir", "Rellenar", "Riempi", "填充", "Preencher"],
                                           arrowKey: nil)
        case .maximize, .minimize: return nil
        }
    }

    /// Locale-independent first: the item's Control+arrow shortcut metadata (the Fn/Globe bit is
    /// not in the mask, so macOS's Fn-Control-arrow tiling shortcut reads as Control+arrow here).
    /// Falls back to a small set of localized titles.
    private static func matches(_ item: AXUIElement, _ spec: TileSpec) -> Bool {
        if let key = spec.arrowKey, let mods = intAttr(item, "AXMenuItemCmdModifiers" as CFString) {
            let controlPresent = (mods & 0x4) != 0
            let commandAbsent = (mods & 0x8) != 0
            if controlPresent && commandAbsent,
               intAttr(item, "AXMenuItemCmdVirtualKey" as CFString) == key { return true }
        }
        return spec.titles.contains(string(item, kAXTitleAttribute as CFString) ?? "")
    }

    private static func findItem(in menu: AXUIElement, spec: TileSpec) -> AXUIElement? {
        for item in children(menu) {
            if matches(item, spec) { return item }
            if let submenu = children(item).first(where: isMenu),
               let hit = findItem(in: submenu, spec: spec) { return hit }
        }
        return nil
    }

    // MARK: - Menu navigation

    /// The `AXMenu` owned by the menu bar's "Window" item.
    private static func windowMenu(in menuBar: AXUIElement) -> AXUIElement? {
        let titles: Set<String> = ["Window", "윈도우", "ウインドウ", "Fenster", "Fenêtre",
                                    "Ventana", "Finestra", "窗口", "Janela"]
        let items = children(menuBar)
        let windowItem = items.first { titles.contains(string($0, kAXTitleAttribute as CFString) ?? "") }
            ?? (items.count >= 2 ? items[items.count - 2] : nil)   // conventionally …, Window, Help
        guard let windowItem else { return nil }
        return children(windowItem).first(where: isMenu)
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
