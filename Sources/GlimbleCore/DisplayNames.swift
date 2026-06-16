public extension RecognizedGesture {
    var displayName: String {
        switch self {
        case .swipe(let fingers, let direction):
            return "\(fingers)-finger swipe \(direction.rawValue)"
        case .tap(let fingers):
            return "\(fingers)-finger tap"
        case .doubleTap(let fingers):
            return "\(fingers)-finger double tap"
        }
    }
}

public extension SnapPosition {
    var displayName: String {
        switch self {
        case .left: return "Snap left";        case .right: return "Snap right"
        case .top: return "Snap top";          case .bottom: return "Snap bottom"
        case .topLeft: return "Snap top-left";  case .topRight: return "Snap top-right"
        case .bottomLeft: return "Snap bottom-left"; case .bottomRight: return "Snap bottom-right"
        case .maximize: return "Maximize window"; case .center: return "Center window"
        }
    }
}

public extension GlimbleAction {
    var displayName: String {
        switch self {
        case .keyboardShortcut: return "Keyboard shortcut"
        case .shell: return "Run shell command"
        case .appleScript: return "Run AppleScript"
        case .runShortcut(let name): return "Run Shortcut “\(name)”"
        case .launchApp(let bundleID): return "Launch \(bundleID)"
        case .window(let pos): return pos.displayName
        }
    }
}
