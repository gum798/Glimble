import Foundation

/// Lightweight user preferences, persisted in UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    @Published var doubleTapWindow: Double {
        didSet { UserDefaults.standard.set(doubleTapWindow, forKey: Self.key) }
    }
    private static let key = "doubleTapWindow"

    init() {
        let stored = UserDefaults.standard.double(forKey: Self.key)
        doubleTapWindow = stored > 0 ? stored : 0.3
    }
}
