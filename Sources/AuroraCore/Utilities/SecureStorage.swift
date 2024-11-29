//
//  SecureStorage.swift
//
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation
import Security

/**
 `SecureStorage` is responsible for securely saving, retrieving, and deleting API keys and base URLs using the Keychain on Apple devices.
 This is useful for storing sensitive information like API keys and custom base URLs in a secure and persistent manner.
 */
public class SecureStorage {

    /**
     Saves an API key to the secure storage (Keychain) for a specific service.

     - Parameter key: The API key to be saved.
     - Parameter serviceName: The name of the service associated with the API key (e.g., "OpenAI", "Anthropic", "Ollama").
     - Returns: A boolean indicating whether the key was saved successfully.
     */
    @discardableResult
    public static func saveAPIKey(_ key: String, for serviceName: String) -> Bool {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: serviceName + "_apiKey",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        // Remove any existing key for the service before saving the new one
        SecItemDelete(query as CFDictionary)
        // Add the new key
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /**
     Retrieves an API key from the secure storage (Keychain) for a specific service.

     - Parameter serviceName: The name of the service for which the API key is retrieved.
     - Returns: The API key as a string, or `nil` if the key is not found.
     */
    public static func getAPIKey(for serviceName: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: serviceName + "_apiKey",
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    /**
     Deletes an API key from the secure storage (Keychain) for a specific service.

     - Parameter serviceName: The name of the service whose API key should be deleted.
     */
    public static func deleteAPIKey(for serviceName: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: serviceName + "_apiKey"
        ]
        SecItemDelete(query as CFDictionary)
    }

    /**
     Saves the base URL to the secure storage (Keychain) for a specific service.

     - Parameter url: The base URL to be saved.
     - Parameter serviceName: The name of the service associated with the base URL (e.g., "Ollama").
     - Returns: A boolean indicating whether the base URL was saved successfully.
     */
    @discardableResult
    public static func saveBaseURL(_ url: String, for serviceName: String) -> Bool {
        let data = Data(url.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: serviceName + "_baseURL",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        // Remove any existing base URL for the service before saving the new one
        SecItemDelete(query as CFDictionary)
        // Add the new base URL
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /**
     Retrieves the base URL from the secure storage (Keychain) for a specific service.

     - Parameter serviceName: The name of the service for which the base URL is retrieved.
     - Returns: The base URL as a string, or `nil` if the base URL is not found.
     */
    public static func getBaseURL(for serviceName: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: serviceName + "_baseURL",
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    /**
     Deletes the base URL from the secure storage (Keychain) for a specific service.

     - Parameter serviceName: The name of the service whose base URL should be deleted.
     */
    public static func deleteBaseURL(for serviceName: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: serviceName + "_baseURL"
        ]
        SecItemDelete(query as CFDictionary)
    }

    /**
     Clears all API keys and base URLs from the secure storage (Keychain).

     This method removes all entries saved by the app in the Keychain. Use with caution as this may affect multiple services.

     - Note: This is an optional method that can be used for testing or when you need to reset stored keys.
     */
    public static func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        SecItemDelete(query as CFDictionary)
    }
}
