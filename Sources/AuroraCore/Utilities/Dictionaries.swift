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
    func mapKeys<NewKey: Hashable>(_ transform: (Key) -> NewKey) -> [NewKey: Value] {
        return Dictionary<NewKey, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}
