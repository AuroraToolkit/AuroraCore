//
//  JSONElementTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/16/25.
//

import XCTest
@testable import AuroraTaskLibrary

final class JSONElementTests: XCTestCase {

    func testInitFromJSONString() throws {
        // Arrange
        let jsonString = """
        {
            "name": "John",
            "age": 30,
            "isEmployed": true,
            "skills": ["Swift", "Objective-C"],
            "meta": null
        }
        """
        let jsonData = jsonString.data(using: .utf8)!

        // Act
        let element = JSONElement(data: jsonData)

        // Assert
        XCTAssertNotNil(element)
        XCTAssertEqual(element?["name"]?.asString, "John")
        XCTAssertEqual(element?["age"]?.asInt, 30)
        XCTAssertEqual(element?["isEmployed"]?.asBool, true)
        XCTAssertEqual(element?["skills"]?.asStringArray, ["Swift", "Objective-C"])
        XCTAssertTrue(element?["meta"]?.isNull ?? false)
    }

    func testInitFromInvalidData() throws {
        // Arrange
        let invalidData = "invalid json".data(using: .utf8)!

        // Act
        let element = JSONElement(data: invalidData)

        // Assert
        XCTAssertNil(element)
    }

    func testSubscriptObject() throws {
        // Arrange
        let jsonObject: [String: Any] = [
            "name": "Jane",
            "age": 25
        ]
        let element = JSONElement(from: jsonObject)

        // Act
        let name = element["name"]?.asString
        let age = element["age"]?.asInt

        // Assert
        XCTAssertEqual(name, "Jane")
        XCTAssertEqual(age, 25)
    }

    func testSubscriptArray() throws {
        // Arrange
        let jsonArray: [Any] = ["Swift", "Kotlin", "TypeScript"]
        let element = JSONElement(from: jsonArray)

        // Act
        let firstElement = element[0]?.asString
        let thirdElement = element[2]?.asString

        // Assert
        XCTAssertEqual(firstElement, "Swift")
        XCTAssertEqual(thirdElement, "TypeScript")
    }

    func testEquality() throws {
        // Arrange
        let jsonObject1: [String: Any] = ["key": "value", "num": 1]
        let jsonObject2: [String: Any] = ["key": "value", "num": 1]
        let element1 = JSONElement(from: jsonObject1)
        let element2 = JSONElement(from: jsonObject2)

        // Assert
        XCTAssertEqual(element1, element2)
    }

    func testInequality() throws {
        // Arrange
        let jsonObject1: [String: Any] = ["key": "value", "num": 1]
        let jsonObject2: [String: Any] = ["key": "differentValue", "num": 2]
        let element1 = JSONElement(from: jsonObject1)
        let element2 = JSONElement(from: jsonObject2)

        // Assert
        XCTAssertNotEqual(element1, element2)
    }

    func testDebugDescription() throws {
        // Arrange
        let jsonObject: [String: Any] = [
            "name": "Jane",
            "details": ["age": 25, "employed": true]
        ]
        let element = JSONElement(from: jsonObject)

        // Act
        let description = element.debugDescription

        // Assert
        XCTAssertEqual(description, "{details: {age: 25, employed: 1}, name: \"Jane\"}")
    }

    func testToJSONString() throws {
        // Arrange
        let jsonObject: [String: Any] = ["name": "John", "age": 30]
        let element = JSONElement(from: jsonObject)

        // Act
        let jsonString = element.toJSONString()

        // Assert
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString!.contains("\"name\":\"John\""))
        XCTAssertTrue(jsonString!.contains("\"age\":30"))
    }

    func testToJSONData() throws {
        // Arrange
        let jsonObject: [String: Any] = ["name": "John", "age": 30]
        let element = JSONElement(from: jsonObject)

        // Act
        let jsonData = element.toJSONData()

        // Assert
        XCTAssertNotNil(jsonData)
        let decoded = try JSONSerialization.jsonObject(with: jsonData!) as? [String: Any]
        XCTAssertEqual(decoded?["name"] as? String, "John")
        XCTAssertEqual(decoded?["age"] as? Int, 30)
    }

    func testNullEquality() throws {
        // Assert
        XCTAssertEqual(JSONElement.null, JSONElement.null)
    }

    func testAsTypeConversions() throws {
        // Arrange
        let elementString = JSONElement.string("Hello")
        let elementNumber = JSONElement.number(NSNumber(value: 42))
        let elementBool = JSONElement.number(NSNumber(value: true))

        // Assert
        XCTAssertEqual(elementString.asString, "Hello")
        XCTAssertEqual(elementNumber.asInt, 42)
        XCTAssertEqual(elementBool.asBool, true)
    }

    func testComplexJSONParsing() throws {
        // Arrange
        let jsonString = """
        {
            "users": [
                {"id": 1, "name": "Alice"},
                {"id": 2, "name": "Bob"}
            ],
            "count": 2
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        let element = JSONElement(data: jsonData)

        // Act
        let users = element?["users"]?.asArray
        let count = element?["count"]?.asInt

        // Assert
        XCTAssertEqual(users?.count, 2)
        XCTAssertEqual(users?[0]["name"]?.asString, "Alice")
        XCTAssertEqual(users?[1]["name"]?.asString, "Bob")
        XCTAssertEqual(count, 2)
    }

    func testAsObjectConversion() throws {
        // Arrange: Valid object JSON
        let validObject: [String: Any] = [
            "key1": "value1",
            "key2": 42,
            "key3": true
        ]
        let validElement = JSONElement(from: validObject)

        // Act: Conversion to object
        let convertedObject = validElement.asObject

        // Assert: Verify the conversion
        XCTAssertNotNil(convertedObject)
        XCTAssertEqual(convertedObject?["key1"], .string("value1"))
        XCTAssertEqual(convertedObject?["key2"], .number(42))
        XCTAssertEqual(convertedObject?["key3"], .number(1))

        // Arrange: Invalid non-object JSON
        let invalidElement = JSONElement.array([.string("value1"), .number(42), .number(1)])

        // Act: Attempt to convert non-object to object
        let invalidConversion = invalidElement.asObject

        // Assert: Ensure invalid conversion is nil
        XCTAssertNil(invalidConversion)
    }

    func testAsStringArray() throws {
        // Arrange
        let jsonArray: [Any] = ["Swift", "Kotlin", "Python"]
        let element = JSONElement(from: jsonArray)

        // Act
        let result = element.asStringArray

        // Assert
        XCTAssertEqual(result, ["Swift", "Kotlin", "Python"])
    }

    func testAsNumberArray() throws {
        // Arrange
        let jsonArray: [Any] = [1, 2.5, 3]
        let element = JSONElement(from: jsonArray)

        // Act
        let result = element.asNumberArray

        // Assert
        XCTAssertEqual(result, [1, 2.5, 3])
    }

    func testAsBoolArray() throws {
        // Arrange
        let jsonArray: [Any] = [true, false, true]
        let element = JSONElement(from: jsonArray)

        // Act
        let result = element.asBoolArray

        // Assert
        XCTAssertEqual(result, [true, false, true])
    }

    func testAsIntArray() throws {
        // Arrange
        let jsonArray: [Any] = [1, 2, 3]
        let element = JSONElement(from: jsonArray)

        // Act
        let result = element.asIntArray

        // Assert
        XCTAssertEqual(result, [1, 2, 3])
    }

    func testAsDoubleArray() throws {
        // Arrange
        let jsonArray: [Any] = [1.1, 2.2, 3.3]
        let element = JSONElement(from: jsonArray)

        // Act
        let result = element.asDoubleArray

        // Assert
        XCTAssertEqual(result, [1.1, 2.2, 3.3])
    }

    func testAsFloatArray() throws {
        // Arrange
        let jsonArray: [Any] = [1.1, 2.2, 3.3]
        let element = JSONElement(from: jsonArray)

        // Act
        let result = element.asFloatArray

        // Assert
        XCTAssertEqual(result, [1.1, 2.2, 3.3])
    }

    func testAsDecimalArray() throws {
        // Arrange
        let jsonArray: [Any] = [1.1, 2.2, 3.3]
        let element = JSONElement(from: jsonArray)

        // Act
        let result = element.asDecimalArray

        // Assert
        XCTAssertEqual(result, [Decimal(1.1), Decimal(2.2), Decimal(3.3)])
    }

    func testAsStringArrayWithValidStrings() {
        let jsonArray: JSONElement = .array([.string("Hello"), .string("World")])
        XCTAssertEqual(jsonArray.asStringArray, ["Hello", "World"])
    }

    func testAsStringArrayWithMixedTypes() {
        let jsonArray: JSONElement = .array([.string("Hello"), .number(42), .null])
        XCTAssertEqual(jsonArray.asStringArray, ["Hello"])
    }

    func testAsStringArrayWithEmptyArray() {
        let jsonArray: JSONElement = .array([])
        XCTAssertEqual(jsonArray.asStringArray, [])
    }

    func testAsStringArrayWithNonArray() {
        let jsonObject: JSONElement = .object(["key": .string("value")])
        XCTAssertEqual(jsonObject.asStringArray, [])
    }

    func testAsNumberArrayWithValidNumbers() {
        let jsonArray: JSONElement = .array([.number(42), .number(3.14)])
        XCTAssertEqual(jsonArray.asNumberArray, [42, 3.14])
    }

    func testAsNumberArrayWithMixedTypes() {
        let jsonArray: JSONElement = .array([.number(42), .string("NotANumber"), .null])
        XCTAssertEqual(jsonArray.asNumberArray, [42])
    }

    func testAsNumberArrayWithEmptyArray() {
        let jsonArray: JSONElement = .array([])
        XCTAssertEqual(jsonArray.asNumberArray, [])
    }

    func testAsNumberArrayWithNonArray() {
        let jsonObject: JSONElement = .object(["key": .number(123)])
        XCTAssertEqual(jsonObject.asNumberArray, [])
    }

    func testAsBoolArrayWithValidBooleans() {
        let jsonArray: JSONElement = .array([.number(1), .number(0)])
        XCTAssertEqual(jsonArray.asBoolArray, [true, false])
    }

    func testAsBoolArrayWithMixedTypes() {
        let jsonArray: JSONElement = .array([.number(1), .string("false"), .null])
        XCTAssertEqual(jsonArray.asBoolArray, [true])
    }

    func testAsBoolArrayWithEmptyArray() {
        let jsonArray: JSONElement = .array([])
        XCTAssertEqual(jsonArray.asBoolArray, [])
    }

    func testAsBoolArrayWithNonArray() {
        let jsonObject: JSONElement = .object(["key": .number(1)])
        XCTAssertEqual(jsonObject.asBoolArray, [])
    }

    func testAsIntArrayWithValidIntegers() {
        let jsonArray: JSONElement = .array([.number(42), .number(100)])
        XCTAssertEqual(jsonArray.asIntArray, [42, 100])
    }

    func testAsIntArrayWithMixedTypes() {
        let jsonArray: JSONElement = .array([.number(42), .string("100"), .null])
        XCTAssertEqual(jsonArray.asIntArray, [42])
    }

    func testAsIntArrayWithEmptyArray() {
        let jsonArray: JSONElement = .array([])
        XCTAssertEqual(jsonArray.asIntArray, [])
    }

    func testAsIntArrayWithNonArray() {
        let jsonObject: JSONElement = .object(["key": .number(123)])
        XCTAssertEqual(jsonObject.asIntArray, [])
    }

    func testAsDoubleArrayWithValidDoubles() {
        let jsonArray: JSONElement = .array([.number(3.14), .number(2.718)])
        XCTAssertEqual(jsonArray.asDoubleArray, [3.14, 2.718])
    }

    func testAsDoubleArrayWithMixedTypes() {
        let jsonArray: JSONElement = .array([.number(3.14), .string("NaN"), .null])
        XCTAssertEqual(jsonArray.asDoubleArray, [3.14])
    }

    func testAsDoubleArrayWithEmptyArray() {
        let jsonArray: JSONElement = .array([])
        XCTAssertEqual(jsonArray.asDoubleArray, [])
    }

    func testAsDoubleArrayWithNonArray() {
        let jsonObject: JSONElement = .object(["key": .number(3.14)])
        XCTAssertEqual(jsonObject.asDoubleArray, [])
    }
}
