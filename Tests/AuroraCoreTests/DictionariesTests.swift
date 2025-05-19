//
//  DictionariesTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/19/25.
//

import XCTest
@testable import AuroraCore

final class DictionariesTests: XCTestCase {

    func testMapKeys() {
        let original = ["one": 1, "two": 2, "three": 3]
        let transformed = original.mapKeys { $0.uppercased() }

        XCTAssertEqual(transformed, ["ONE": 1, "TWO": 2, "THREE": 3])
    }

    func testResolveWithString() {
        let dictionary: [String: Any] = ["key1": "value1", "key2": "value2"]

        XCTAssertEqual(dictionary.resolve(key: "key1", fallback: "default"), "value1")
        XCTAssertEqual(dictionary.resolve(key: "key3", fallback: "default"), "default")
    }

    func testResolveWithArray() {
        let dictionary: [String: Any] = ["key1": ["one", "two"], "key2": [1, 2, 3]]

        XCTAssertEqual(dictionary.resolve(key: "key1", fallback: []), ["one", "two"])
        XCTAssertEqual(dictionary.resolve(key: "key2", fallback: []), [1, 2, 3])
        XCTAssertEqual(dictionary.resolve(key: "key3", fallback: ["default"]), ["default"])
    }

    func testResolveWithInt() {
        let dictionary: [String: Any] = ["key1": 123, "key2": 456]

        XCTAssertEqual(dictionary.resolve(key: "key1", fallback: 0), 123)
        XCTAssertEqual(dictionary.resolve(key: "key2", fallback: 0), 456)
        XCTAssertEqual(dictionary.resolve(key: "key3", fallback: 789), 789)
    }

    func testResolveWithDouble() {
        let dictionary: [String: Any] = ["key1": 123.45, "key2": 67.89]

        XCTAssertEqual(dictionary.resolve(key: "key1", fallback: 0.0), 123.45)
        XCTAssertEqual(dictionary.resolve(key: "key2", fallback: 0.0), 67.89)
    }

    func testResolveWithFloat() {
        let dictionary: [String: Any] = ["key1": Float(123.45), "key2": Float(67.89)]

        XCTAssertEqual(dictionary.resolve(key: "key1", fallback: Float(0.0)), Float(123.45))
        XCTAssertEqual(dictionary.resolve(key: "key2", fallback: Float(0.0)), Float(67.89))
    }

    func testResolveWithBool() {
        let dictionary: [String: Any] = ["key1": true, "key2": false]

        XCTAssertTrue(dictionary.resolve(key: "key1", fallback: false))
        XCTAssertFalse(dictionary.resolve(key: "key2", fallback: true))
    }

    func testResolveWithDate() {
        let date = Date()
        let dictionary: [String: Any] = ["key1": date]

        XCTAssertEqual(dictionary.resolve(key: "key1", fallback: Date(timeIntervalSince1970: 1234567)), date)
    }

    func testResolveWithData() {
        let data = Data()
        let dictionary: [String: Any] = ["key1": data]

        XCTAssertEqual(dictionary.resolve(key: "key1", fallback: Data([1, 2, 3, 4, 5])), data)
    }

    func testResolveWithNilFallback() {
        let dictionary: [String: Any] = ["key1": "value1", "key2": 123]

        XCTAssertEqual(dictionary.resolve(key: "key1", fallback: nil), "value1")
        XCTAssertNil(dictionary.resolve(key: "key3", fallback: nil))
    }

    func testResolveWithEmptyArrays() {
        let dictionary: [String: Any] = ["key1": [], "key2": ArraySlice<Int>()]

        XCTAssertEqual(dictionary.resolve(key: "key1", fallback: ["default"]), [])
        XCTAssertEqual(dictionary.resolve(key: "key2", fallback: [0]), [])
        XCTAssertEqual(dictionary.resolve(key: "key3", fallback: ["fallback"]), ["fallback"])
    }
}
