//
//  KeychainHelper.swift
//  BetterVoice
//
//  Secure keychain storage for API keys
//  FR-019: External LLM API key storage
//

import Foundation
import Security

enum KeychainError: Error {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unhandledError(OSStatus)
}

final class KeychainHelper {
    static let shared = KeychainHelper()

    private let service = "com.bettervoice.BetterVoice"

    private init() {}

    // MARK: - Save

    func save(key: String, data: Data) throws {
        // Delete existing item if present
        try? delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateItem
            }
            throw KeychainError.unhandledError(status)
        }
    }

    func save(key: String, string: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try save(key: key, data: data)
    }

    // MARK: - Retrieve

    func retrieve(key: String) throws -> Data {
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
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unhandledError(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    func retrieveString(key: String) throws -> String {
        let data = try retrieve(key: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }

    // MARK: - Delete

    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status)
        }
    }

    // MARK: - Update

    func update(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                // Item doesn't exist, create it
                try save(key: key, data: data)
                return
            }
            throw KeychainError.unhandledError(status)
        }
    }

    func update(key: String, string: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try update(key: key, data: data)
    }

    // MARK: - Check Existence

    func exists(key: String) -> Bool {
        do {
            _ = try retrieve(key: key)
            return true
        } catch {
            return false
        }
    }

    // MARK: - API Key Helpers

    func saveAPIKey(provider: String, apiKey: String) throws {
        let key = "api_key_\(provider.lowercased())"
        try save(key: key, string: apiKey)
    }

    func retrieveAPIKey(provider: String) throws -> String {
        let key = "api_key_\(provider.lowercased())"
        return try retrieveString(key: key)
    }

    func deleteAPIKey(provider: String) throws {
        let key = "api_key_\(provider.lowercased())"
        try delete(key: key)
    }
}
