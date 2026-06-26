import Foundation
import Security

// A tiny Keychain-backed Bool store. App Group UserDefaults don't reliably survive an
// app deletion (the shared *files* do, but the defaults get cleared), so a preference
// that must outlive a reinstall — like the iCloud Sync toggle — is kept here instead.
//
// Items are marked synchronizable, so with iCloud Keychain on they also sync across the
// user's devices (enable sync on one device, it's known on the others); with iCloud
// Keychain off they stay device-local but still survive delete + reinstall. No extra
// entitlement required.
enum KeychainStore {
    static func bool(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: true,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, let first = data.first
        else { return false }
        return first == 1
    }

    static func set(_ value: Bool, forKey key: String) {
        // Clear any existing copy (synced or not) before writing the synced one.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: true,
            kSecValueData as String: Data([value ? 1 : 0]),
            // Must be a non-"ThisDeviceOnly" accessibility for the item to be syncable.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(add as CFDictionary, nil)
    }
}
