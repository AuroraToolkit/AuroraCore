//
//  TypeHandlingTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/19/25.
//

import XCTest
import Foundation
@testable import AuroraCore

final class TypeHandlingTests: XCTestCase {

    func testAsArrayWithValidArray() {
        let array: [String] = ["one", "two", "three"]
        XCTAssertEqual(asArray(array, of: String.self), array)

        let intArray: [Int] = [1, 2, 3]
        XCTAssertEqual(asArray(intArray, of: Int.self), intArray)
    }

    func testAsArrayWithArraySlice() {
        let arraySlice: ArraySlice<String> = ["one", "two", "three"][1...2]
        XCTAssertEqual(asArray(arraySlice, of: String.self), ["two", "three"])

        let intSlice: ArraySlice<Int> = [1, 2, 3][0...1]
        XCTAssertEqual(asArray(intSlice, of: Int.self), [1, 2])
    }

    func testAsArrayWithInvalidType() {
        let array: [Any] = ["one", 2, 3.0]
        XCTAssertNil(asArray(array, of: String.self))
        XCTAssertNil(asArray(array, of: Int.self))
    }

    func testUnwrapOptionalType() {
        XCTAssertEqual(String(describing: unwrapOptionalType(Optional<String>.self)), String(describing: String.self))
        XCTAssertEqual(String(describing: unwrapOptionalType(Optional<Int>.self)), String(describing: Int.self))
        XCTAssertEqual(String(describing: unwrapOptionalType(String.self)), String(describing: String.self))
        XCTAssertEqual(String(describing: unwrapOptionalType(Int.self)), String(describing: Int.self))
    }

    func testUnwrapOptionalTypeWithDoubleOptional() {
        XCTAssertEqual(String(describing: unwrapOptionalType(Optional<String>.self)), String(describing: String.self))
        XCTAssertEqual(String(describing: unwrapOptionalType(Optional<Int>.self)), String(describing: Int.self))
        XCTAssertEqual(String(describing: unwrapOptionalType(String.self)), String(describing: String.self))
    }
}
