//
//  Dictionaries.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/17/24.
//

import Foundation

extension Dictionary {
    /**
     Returns a new dictionary with transformed keys while keeping the same values.

     - Parameter transform: A closure that takes a key of the dictionary as input and returns a transformed key.
     - Returns: A new dictionary with transformed keys.

     - Note:This is used for example, to prefix task group names to keys in task output.
     */
    public func mapKeys<NewKey: Hashable>(_ transform: (Key) -> NewKey) -> [NewKey: Value] {
        return Dictionary<NewKey, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}

extension Dictionary where Key == String {
    /**
     Resolves a value from the dictionary by its key.
     If the key exists in the dictionary, its value is returned (even if `nil`). Otherwise, the provided fallback value is returned.

     - Parameters:
        - key: The key to resolve.
        - fallback: The fallback value to use if the key does not exist in the dictionary.
     - Returns: The resolved value or the fallback.
     */
    public func resolve<T>(key: String, fallback: T?) -> T? {
        if self.keys.contains(key) {
            return self[key] as? T
        }
        return fallback
    }
}
