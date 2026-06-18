import Foundation

/// A small dotted-numeric version (e.g. `0.1.3`), tolerant of a leading `v` and of
/// missing trailing components (`0.1` → `0.1.0`). Pre-release/build suffixes are ignored.
/// Pure and `Comparable` so update-checking logic stays testable in `GlimbleCore`.
public struct SemanticVersion: Comparable, Equatable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major; self.minor = minor; self.patch = patch
    }

    /// Parses `"v0.1.3"`, `"0.1.3"`, `"0.1"`, … Returns nil for non-numeric input (e.g. `"dev"`).
    public init?(_ raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = s.first, first == "v" || first == "V" { s.removeFirst() }
        // Keep only the leading dotted-numeric core, dropping any `-beta`/`+build` suffix.
        let core = s.prefix { $0.isNumber || $0 == "." }
        let parts = core.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }
        let nums = parts.map { $0! }
        major = nums[0]
        minor = nums.count > 1 ? nums[1] : 0
        patch = nums.count > 2 ? nums[2] : 0
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    public var description: String { "\(major).\(minor).\(patch)" }
}
