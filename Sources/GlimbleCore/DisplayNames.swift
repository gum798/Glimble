public extension RecognizedGesture {
    var displayName: String {
        switch self {
        case .swipe(let fingers, let direction):
            return "\(fingers)-finger swipe \(direction.rawValue)"
        case .tap(let fingers):
            return "\(fingers)-finger tap"
        case .doubleTap(let fingers):
            return "\(fingers)-finger double tap"
        case .tripleTap(let fingers):
            return "\(fingers)-finger triple tap"
        case .pinch(let fingers, let zoom):
            return "\(fingers)-finger zoom \(zoom.rawValue)"
        case .rotate(let f, let d):
            return "\(f)-finger rotate " + (d == .clockwise ? "clockwise" : "counterclockwise")
        case .longPress(let f):
            return "\(f)-finger long press"
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
        case .fill: return "Fill screen"
        case .minimize: return "Minimize to Dock"
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
