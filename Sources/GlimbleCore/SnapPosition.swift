/// A target region for snapping the focused window, expressed independently of any
/// coordinate system. Geometry is resolved against a visible frame in `WindowGeometry`.
public enum SnapPosition: String, CaseIterable, Sendable {
    case left, right, top, bottom
    case topLeft, topRight, bottomLeft, bottomRight
    case maximize, center
}
