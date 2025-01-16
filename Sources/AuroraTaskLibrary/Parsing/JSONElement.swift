//
//  JSONElement.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/16/25.
//

import Foundation

/**
    A representation of a JSON element for structured JSON parsing.

    This enum can represent any JSON structure, including objects, arrays, strings, numbers, booleans, and null values.
 */
public enum JSONElement: Equatable {
    case object([String: JSONElement])
    case array([JSONElement])
    case string(String)
    case number(NSNumber)   // All numeric values, including booleans as 0(false)/1(true)
    case null

    /**
        Initializes a new JSON element from a given JSON object.

        - Parameters:
            - jsonObject: The JSON object to convert to a JSONElement.
        - Returns a JSONElement representing the JSON object.
     */
    public init(from jsonObject: Any) {
        if let dictionary = jsonObject as? [String: Any] {
            self = .object(dictionary.mapValues { JSONElement(from: $0) })
        } else if let array = jsonObject as? [Any] {
            self = .array(array.map { JSONElement(from: $0) })
        } else if let string = jsonObject as? String {
            self = .string(string)
        } else if let number = jsonObject as? NSNumber {
            self = .number(number)
        } else {
            self = .null
        }
    }

    /**
        Initializes a new JSON element from a given data object.

        - Parameters:
            - data: The data object to convert to a JSONElement.
        - Returns a JSONElement representing the data object, or `nil` if the data is not valid JSON
     */
    public init?(data: Data) {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        self.init(from: jsonObject)
    }

    /// Debug description for pretty-printing the JSON element.
    public var debugDescription: String {
        switch self {
        case .object(let dictionary):
            let sortedKeys = dictionary.keys.sorted() // Sort keys alphabetically
            let sortedDictionary = sortedKeys.map { "\($0): \(dictionary[$0]!.debugDescription)" }
            return "{\(sortedDictionary.joined(separator: ", "))}"
        case .array(let array):
            return "[\(array.map { $0.debugDescription }.joined(separator: ", "))]"
        case .string(let string):
            return "\"\(string)\""
        case .number(let number):
            return "\(number)"
        case .null:
            return "null"
        }
    }

    /// Returns `true` if the JSONElement represents a `null` value.
    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    /**
        Subscript access to the JSON object by key.

        - Parameters:
            - key: The key to access in the JSON object.
        - Returns: The JSONElement for the given key, or `nil` if the key is not found or the JSONElement is not an object.
     */
    public subscript(key: String) -> JSONElement? {
        if case let .object(object) = self {
            return object[key]
        }
        /// `key` not found in object
        return nil
    }

    /**
        Subscript access to the JSON array by index.

        - Parameters:
            - index: The index to access in the JSON array.
        - Returns: The JSONElement for the given index, or `nil` if the index is out of bounds or the JSONElement is not an array.
     */
    public subscript(index: Int) -> JSONElement? {
        if case let .array(array) = self, array.indices.contains(index) {
            return array[index]
        }
        /// `index` out of bounds in array, or not an array
        return nil
    }

    /// Returns the JSONElement as a dictionary, or `nil` if it is not an object.
    public var asObject: [String: JSONElement]? {
        if case let .object(dictionary) = self {
            return dictionary
        }
        return nil
    }

    /// Returns the JSONElement as an array, or `nil` if it is not an array.
    public var asArray: [JSONElement]? {
        if case let .array(array) = self {
            return array
        }
        return nil
    }

    /// Returns the JSONElement as a string, or `nil` if it is not a string.
    public var asString: String? {
        if case let .string(string) = self {
            return string
        }
        return nil
    }

    /// Returns the JSONElement as a `NSNumber`, or `nil` if it is not a number.
    public var asNumber: NSNumber? {
        if case let .number(number) = self {
            return number
        }
        return nil
    }

    /// Returns the JSONElement as a `Bool`, or `nil` if it is not a boolean.
    public var asBool: Bool? {
        if case let .number(number) = self {
            return number.boolValue
        }
        return nil
    }

    /// Returns the JSONElement as an `Int`, or `nil` if it is not an integer.
    public var asInt: Int? {
        if case let .number(number) = self {
            return number.intValue
        }
        return nil
    }

    /// Returns the JSONElement as a `Double`, or `nil` if it is not a double.
    public var asDouble: Double? {
        if case let .number(number) = self {
            return number.doubleValue
        }
        return nil
    }

    /// Returns the JSONElement as a `Float`, or `nil` if it is not a float.
    public var asFloat: Float? {
        if case let .number(number) = self {
            return number.floatValue
        }
        return nil
    }

    /// Returns the JSONElement as a `Decimal`, or `nil` if it is not a decimal
    public var asDecimal: Decimal? {
        if case let .number(number) = self {
            return number.decimalValue
        }
        return nil
    }

    /// Returns the JSONElement as a `String` array, or an empty array if it is not an array of `String`.
    public var asStringArray: [String]? {
        if case let .array(array) = self {
            return array.compactMap { $0.asString }
        }
        return []
    }

    /// Returns the JSONElement as a `NSNumber` array, or an empty array if it is not an array of `NSNumber`.
    public var asNumberArray: [NSNumber]? {
        if case let .array(array) = self {
            return array.compactMap { $0.asNumber }
        }
        return []
    }

    /// Returns the JSONElement as a `Bool` array, or an empty array if it is not an array of `Bool`.
    public var asBoolArray: [Bool]? {
        if case let .array(array) = self {
            return array.compactMap { $0.asBool }
        }
        return []
    }

    /// Returns the JSONElement as an `Int` array, or an empty array if it is not an array of `Int`.
    public var asIntArray: [Int]? {
        if case let .array(array) = self {
            return array.compactMap { $0.asInt }
        }
        return []
    }

    /// Returns the JSONElement as a `Double` array, or an empty array if it is not an array of `Double`.
    public var asDoubleArray: [Double]? {
        if case let .array(array) = self {
            return array.compactMap { $0.asDouble }
        }
        return []
    }

    /// Returns the JSONElement as a `Float` array, or an empty array if it is not an array of `Float`.
    public var asFloatArray: [Float]? {
        if case let .array(array) = self {
            return array.compactMap { $0.asFloat }
        }
        return []
    }

    /// Returns the JSONElement as a `Decimal` array, or an empty array if it is not an array of `Decimal`.
    public var asDecimalArray: [Decimal]? {
        if case let .array(array) = self {
            return array.compactMap { $0.asDecimal }
        }
        return []
    }

    /// Returns the JSONElement as a `Data` object of the JSON representation, or `nil` if it cannot be converted to an `Array` or `Dictionary`.
    public func toJSONData() -> Data? {
        switch self {
        case .object(let dict):
            let jsonObject = dict.mapValues { $0.toAny() }
            return try? JSONSerialization.data(withJSONObject: jsonObject, options: [])
        case .array(let array):
            let jsonArray = array.map { $0.toAny() }
            return try? JSONSerialization.data(withJSONObject: jsonArray, options: [])
        default:
            return nil
        }
    }

    /**
        Returns the JSONElement as a JSON string.

        - Parameters:
            - prettyPrinted: Whether to format the JSON string with whitespace for readability. Defaults to `false`.
        - Returns: The JSON string representation of the JSONElement, or `nil` if it cannot be converted to a JSON string.
     */
    public func toJSONString(prettyPrinted: Bool = false) -> String? {
        let options: JSONSerialization.WritingOptions = prettyPrinted ? .prettyPrinted : []
        guard let jsonObject = toAny() else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: jsonObject, options: options) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Returns the JSONElement as an `Any` object.
    private func toAny() -> Any? {
        switch self {
        case .object(let dict):
            return dict.mapValues { $0.toAny() }
        case .array(let array):
            return array.map { $0.toAny() }
        case .string(let string):
            return string
        case .number(let number):
            return number
        case .null:
            return NSNull()
        }
    }

    /**
     Compares two JSONElements for equality.

        - Parameters:
            - lhs: The left-hand side JSONElement to compare.
            - rhs: The right-hand side JSONElement to compare.
        - Returns: `true` if the JSONElements are equal, `false` otherwise.

        - Note: This comparison is recursive for objects and arrays.
     */
    public static func == (lhs: JSONElement, rhs: JSONElement) -> Bool {
        switch (lhs, rhs) {
        case (.string(let lhsValue), .string(let rhsValue)):
            return lhsValue == rhsValue
        case (.number(let lhsValue), .number(let rhsValue)):
            return lhsValue == rhsValue
        case (.null, .null):
            return true
        case (.array(let lhsArray), .array(let rhsArray)):
            return lhsArray == rhsArray // Recursively compare elements
        case (.object(let lhsDict), .object(let rhsDict)):
            return lhsDict == rhsDict // Recursively compare key-value pairs
        default:
            return false
        }
    }
}

