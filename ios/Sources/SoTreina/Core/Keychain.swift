import Foundation
import os
import Security

/// Stores the session JWT. `AfterFirstUnlock` (not `WhenUnlocked`) so a
/// Live Activity intent running while the phone is locked can still read it.
enum Keychain {
    private static let service = "com.feroleto.sotreina"
    private static let account = "session-token"
    private static let log = Logger(subsystem: "com.feroleto.sotreina", category: "keychain")

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func readToken() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            // errSecItemNotFound is the normal logged-out case; anything else
            // (e.g. -34018 missing entitlement on a sideloaded build) is a bug
            if status != errSecItemNotFound {
                log.error("read failed: OSStatus \(status, privacy: .public)")
            }
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func saveToken(_ token: String) {
        deleteToken()
        var query = baseQuery
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            log.info("token saved")
        } else {
            log.error("save failed: OSStatus \(status, privacy: .public)")
        }
    }

    static func deleteToken() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
