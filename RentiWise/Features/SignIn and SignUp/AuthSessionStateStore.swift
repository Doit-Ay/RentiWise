import Foundation

enum StoredAuthProvider: String {
    case password
}

enum AuthSessionStateStore {
    private static let providerKey = "auth.lastProvider"

    static func markSignedIn(provider: StoredAuthProvider) {
        UserDefaults.standard.set(provider.rawValue, forKey: providerKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: providerKey)
    }
}
