import CoreGraphics

/// Pure window-geometry math. No AppKit / no OS imports → fully unit-testable.
public enum WindowGeometry {

    /// Target rect for `position` within `vf`, in the SAME coordinate space as `vf`
    /// (AppKit visible frame: bottom-left origin, y grows upward).
    public static func snapRect(_ position: SnapPosition, in vf: CGRect) -> CGRect {
        let halfW = vf.width / 2
        let halfH = vf.height / 2
        switch position {
        case .maximize, .fill:
            return vf
        case .left:
            return CGRect(x: vf.minX, y: vf.minY, width: halfW, height: vf.height)
        case .right:
            return CGRect(x: vf.minX + halfW, y: vf.minY, width: halfW, height: vf.height)
        case .top:
            return CGRect(x: vf.minX, y: vf.minY + halfH, width: vf.width, height: halfH)
        case .bottom:
            return CGRect(x: vf.minX, y: vf.minY, width: vf.width, height: halfH)
        case .topLeft:
            return CGRect(x: vf.minX, y: vf.minY + halfH, width: halfW, height: halfH)
        case .topRight:
            return CGRect(x: vf.minX + halfW, y: vf.minY + halfH, width: halfW, height: halfH)
        case .bottomLeft:
            return CGRect(x: vf.minX, y: vf.minY, width: halfW, height: halfH)
        case .bottomRight:
            return CGRect(x: vf.minX + halfW, y: vf.minY, width: halfW, height: halfH)
        case .center:
            let w = vf.width * 0.6
            let h = vf.height * 0.6
            return CGRect(x: vf.midX - w / 2, y: vf.midY - h / 2, width: w, height: h)
        }
    }

    /// Convert an AppKit rect (bottom-left origin) to the top-left-origin global
    /// Quartz point used by `kAXPositionAttribute`.
    /// `primaryHeight` is the height of the display whose AppKit frame origin is (0,0).
    /// Y is negative for displays stacked above the primary — that is correct.
    public static func axOrigin(forAppKitRect rect: CGRect, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: rect.origin.x, y: primaryHeight - rect.origin.y - rect.size.height)
    }
}
