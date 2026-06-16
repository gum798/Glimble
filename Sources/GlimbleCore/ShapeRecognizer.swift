import CoreGraphics
import Foundation

/// A built-in drawn (unistroke) shape the recognizer can match. Raw values are the JSON encoding.
public enum DrawnShape: String, Codable, Equatable, Sendable, CaseIterable {
    case circle, check, caretUp, caretDown
}

/// A $1-style unistroke recognizer over a path of `CGPoint`s (the multi-finger centroid samples).
///
/// The pipeline is the classic $1 recognizer (Wobbrock et al.): resample to a fixed point count,
/// rotate so the indicative angle is zero, scale to a reference square, translate the centroid to
/// the origin, then score each normalized template by inverse mean point-distance. Pure value type.
public struct ShapeRecognizer: Sendable {
    /// A candidate must score at least this to be returned. Tuned so distinct shapes never collide.
    public var scoreThreshold: Double = 0.80

    private static let sampleCount = 64
    private static let squareSize: CGFloat = 250

    private let templates: [(DrawnShape, [CGPoint])]

    public init() {
        templates = Self.builtin.map { ($0.0, Self.normalize($0.1)) }
    }

    /// The best-matching shape whose score >= `scoreThreshold`, else nil. Returns nil for paths
    /// with too few points or a degenerate (zero-extent) bounding box.
    public func recognize(_ points: [CGPoint]) -> DrawnShape? {
        guard points.count >= 8 else { return nil }
        let (minX, minY, maxX, maxY) = Self.boundingBox(points)
        // A degenerate path (a dot, or a perfectly straight line with no width in one axis) carries
        // no shape — bail before normalization would divide by a zero extent.
        guard (maxX - minX) > 1e-6, (maxY - minY) > 1e-6 else { return nil }

        let candidate = Self.normalize(points)
        guard candidate.count == Self.sampleCount else { return nil }

        let half = 0.5 * (Self.squareSize * Self.squareSize + Self.squareSize * Self.squareSize).squareRoot()
        var best: (shape: DrawnShape, score: Double)?
        for (shape, template) in templates {
            let avg = Self.averageDistance(candidate, template)
            let score = 1 - Double(avg) / Double(half)
            if best == nil || score > best!.score { best = (shape, score) }
        }
        guard let b = best, b.score >= scoreThreshold else { return nil }
        return b.shape
    }

    // MARK: - $1 pipeline (pure / static)

    private static func normalize(_ points: [CGPoint]) -> [CGPoint] {
        var pts = resample(points, n: sampleCount)
        pts = rotateToZero(pts)
        pts = scaleToSquare(pts, size: squareSize)
        pts = translateToOrigin(pts)
        return pts
    }

    /// Resample into `n` equidistant points along the polyline.
    private static func resample(_ points: [CGPoint], n: Int) -> [CGPoint] {
        guard points.count > 1, n > 1 else { return points }
        let interval = pathLength(points) / CGFloat(n - 1)
        guard interval > 0 else { return points }
        var result: [CGPoint] = [points[0]]
        var accumulated: CGFloat = 0
        var pts = points
        var i = 1
        while i < pts.count {
            let prev = pts[i - 1], cur = pts[i]
            let d = distance(prev, cur)
            if accumulated + d >= interval {
                let t = (interval - accumulated) / d
                let q = CGPoint(x: prev.x + t * (cur.x - prev.x), y: prev.y + t * (cur.y - prev.y))
                result.append(q)
                pts.insert(q, at: i)   // continue resampling from the new point
                accumulated = 0
            } else {
                accumulated += d
            }
            i += 1
        }
        // Floating-point drift can leave us one short of n.
        while result.count < n { result.append(points[points.count - 1]) }
        return result
    }

    /// Rotate so the indicative angle (centroid → first point) is zero.
    private static func rotateToZero(_ points: [CGPoint]) -> [CGPoint] {
        let c = centroid(points)
        let p0 = points[0]
        let angle = atan2(c.y - p0.y, c.x - p0.x)
        return rotateBy(points, -angle, about: c)
    }

    private static func rotateBy(_ points: [CGPoint], _ theta: CGFloat, about c: CGPoint) -> [CGPoint] {
        let cosT = cos(theta), sinT = sin(theta)
        return points.map { p in
            let dx = p.x - c.x, dy = p.y - c.y
            return CGPoint(x: dx * cosT - dy * sinT + c.x, y: dx * sinT + dy * cosT + c.y)
        }
    }

    /// Non-uniformly scale the bounding box to `size` × `size`.
    private static func scaleToSquare(_ points: [CGPoint], size: CGFloat) -> [CGPoint] {
        let (minX, minY, maxX, maxY) = boundingBox(points)
        let w = max(maxX - minX, 1e-9), h = max(maxY - minY, 1e-9)
        return points.map { CGPoint(x: ($0.x - minX) * size / w, y: ($0.y - minY) * size / h) }
    }

    /// Translate so the centroid sits at the origin.
    private static func translateToOrigin(_ points: [CGPoint]) -> [CGPoint] {
        let c = centroid(points)
        return points.map { CGPoint(x: $0.x - c.x, y: $0.y - c.y) }
    }

    // MARK: - Scoring helpers

    private static func averageDistance(_ a: [CGPoint], _ b: [CGPoint]) -> CGFloat {
        let n = min(a.count, b.count)
        guard n > 0 else { return .greatestFiniteMagnitude }
        var sum: CGFloat = 0
        for i in 0..<n { sum += distance(a[i], b[i]) }
        return sum / CGFloat(n)
    }

    private static func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        var total: CGFloat = 0
        for i in 1..<points.count { total += distance(points[i - 1], points[i]) }
        return total
    }

    private static func centroid(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    private static func boundingBox(_ points: [CGPoint]) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        var minX = CGFloat.greatestFiniteMagnitude, minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for p in points {
            minX = min(minX, p.x); minY = min(minY, p.y)
            maxX = max(maxX, p.x); maxY = max(maxY, p.y)
        }
        return (minX, minY, maxX, maxY)
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x, dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }

    // MARK: - Built-in templates (raw, un-normalized)

    /// Raw point clouds for each shape; `init` normalizes them through the same pipeline.
    private static let builtin: [(DrawnShape, [CGPoint])] = [
        (.circle, circleTemplate()),
        (.check, denseSegments([CGPoint(x: 0, y: 0.5), CGPoint(x: 0.35, y: 0), CGPoint(x: 1, y: 1)])),
        (.caretUp, denseSegments([CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 1), CGPoint(x: 1, y: 0)])),
        (.caretDown, denseSegments([CGPoint(x: 0, y: 1), CGPoint(x: 0.5, y: 0), CGPoint(x: 1, y: 1)])),
    ]

    private static func circleTemplate(n: Int = 32) -> [CGPoint] {
        (0..<n).map { i in
            let a = 2 * Double.pi * Double(i) / Double(n)
            return CGPoint(x: 0.5 + 0.5 * CGFloat(cos(a)), y: 0.5 + 0.5 * CGFloat(sin(a)))
        }
    }

    /// Sample the corner list densely so resampling has enough fidelity along each segment.
    private static func denseSegments(_ corners: [CGPoint], perSegment: Int = 24) -> [CGPoint] {
        var out: [CGPoint] = []
        for i in 0..<(corners.count - 1) {
            let a = corners[i], b = corners[i + 1]
            for s in 0..<perSegment {
                let t = CGFloat(s) / CGFloat(perSegment)
                out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        out.append(corners.last!)
        return out
    }
}
