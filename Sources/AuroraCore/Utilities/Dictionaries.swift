//
//  Dictionaries.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/17/24.
//

import Foundation

public extension Dictionary {
    /**
     Returns a new dictionary with transformed keys while keeping the same values.

     - Parameter transform: A closure that takes a key of the dictionary as input and returns a transformed key.
     - Returns: A new dictionary with transformed keys.

     - Note:This is used for example, to prefix task group names to keys in task output.
     */
    func mapKeys<NewKey: Hashable>(_ transform: (Key) -> NewKey) -> [NewKey: Value] {
        return [NewKey: Value](uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}

public extension Dictionary where Key == String {
    /**
     Resolves a value from the dictionary by its key.
     If the key exists in the dictionary, its value is returned (even if `nil`). Otherwise, the provided fallback value is returned.

     - Parameters:
        - key: The key to resolve.
        - fallback: The fallback value to use if the key does not exist in the dictionary.
     - Returns: The resolved value or the fallback, which can be `nil`.
     */
    func resolve<T>(key: String, fallback: T?) -> T? {
        return resolveInternal(key: key, fallback: fallback)
    }

    /**
     Resolves a value from the dictionary by its key.
     If the key exists in the dictionary, its value is returned. Otherwise, the provided fallback value is returned.

     - Parameters:
        - key: The key to resolve.
        - fallback: The fallback value to use if the key does not exist in the dictionary.
     - Returns: The resolved value or the fallback.
     */
    func resolve<T>(key: String, fallback: T) -> T {
        return resolveInternal(key: key, fallback: fallback) ?? fallback
    }

    private func resolveInternal<T>(key: String, fallback: T? = nil) -> T? {
        // Retrieve the optional value
        guard let optionalValue = self[key] else {
            return fallback
        }

        let unwrappedType = unwrapOptionalType(T.self)
        switch unwrappedType {
        case is [String].Type:
            return asArray(optionalValue, of: String.self) as? T ?? fallback
        case is [Int].Type:
            return asArray(optionalValue, of: Int.self) as? T ?? fallback
        case is [Double].Type:
            return asArray(optionalValue, of: Double.self) as? T ?? fallback
        case is [Float].Type:
            return asArray(optionalValue, of: Float.self) as? T ?? fallback
        case is [Bool].Type:
            return asArray(optionalValue, of: Bool.self) as? T ?? fallback
        case is [Date].Type:
            return asArray(optionalValue, of: Date.self) as? T ?? fallback
        case is [Data].Type:
            return asArray(optionalValue, of: Data.self) as? T ?? fallback
        default:
            // Handle direct casting
            if let castValue = optionalValue as? T {
                return castValue
            }
        }

        return fallback
    }
}
