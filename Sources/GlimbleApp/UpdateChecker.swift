import Foundation
import GlimbleCore

/// Result of comparing the running build against the newest GitHub release.
enum UpdateStatus {
    case upToDate(current: SemanticVersion)
    case updateAvailable(latest: SemanticVersion, notes: String, page: URL)
    /// Running an unversioned dev build — we can't compare, so just surface the latest release.
    case developmentBuild(latest: SemanticVersion, page: URL)
}

/// Finds the latest published Glimble release by resolving the `releases/latest` redirect
/// (`…/releases/latest` → `…/releases/tag/vX.Y.Z`) and reading the tag from the final URL.
///
/// This deliberately uses the **web** endpoint, not the REST API: the API caps unauthenticated
/// callers at 60 requests/hour per IP and answers 403 once that's spent (which users on shared
/// IPs can hit immediately). The redirect carries no such limit. The trade-off is we don't get
/// release notes inline — the "Release Page" button covers those.
enum UpdateChecker {
    private static let latestURL = URL(string: "https://github.com/gum798/Glimble/releases/latest")!

    static func check(currentVersion: String) async throws -> UpdateStatus {
        var request = URLRequest(url: latestURL)
        request.setValue("Glimble", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<400).contains(http.statusCode) {
            throw UpdateError.server(status: http.statusCode)
        }
        // URLSession follows the redirect, so `response.url` is now …/releases/tag/<tag>.
        // With no releases at all, it stays at …/releases/latest → lastPathComponent "latest" → nil.
        guard let page = response.url,
              let latest = SemanticVersion(page.lastPathComponent) else {
            throw UpdateError.noReleaseFound
        }
        guard let current = SemanticVersion(currentVersion) else {
            return .developmentBuild(latest: latest, page: page)
        }
        return latest > current
            ? .updateAvailable(latest: latest, notes: "", page: page)
            : .upToDate(current: current)
    }
}

enum UpdateError: LocalizedError {
    case server(status: Int)
    case noReleaseFound

    var errorDescription: String? {
        switch self {
        case .server(let status): return "GitHub returned HTTP \(status)."
        case .noReleaseFound:     return "Couldn’t find the latest release."
        }
    }
}
