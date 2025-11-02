//
//  KeychainService.swift
//  SwiftShelf
//
//  Created by michaeldvinci on 11/2/25.
//

import Foundation
import Security

final class KeychainService {
    private static let service = Bundle.main.bundleIdentifier ?? "com.swiftshelf"

    enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case invalidData
        case unexpectedStatus(OSStatus)
    }

    /// Store a string value in Keychain
    static func set(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // Try to update existing item first
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Item doesn't exist, create it
            var newItem = query
            newItem[kSecValueData as String] = data

            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    /// Retrieve a string value from Keychain
    static func get(forKey key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw status == errSecItemNotFound ? KeychainError.itemNotFound : KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return string
    }

    /// Delete a value from Keychain
    static func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
