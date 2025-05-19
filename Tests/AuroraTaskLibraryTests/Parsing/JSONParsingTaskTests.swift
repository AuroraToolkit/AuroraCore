//
//  JSONParsingTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/13/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraTaskLibrary

final class JSONParsingTaskTests: XCTestCase {

    func testParseSimpleJSON() async throws {
        // Arrange: Simple JSON
        let jsonString = """
        {
            "name": "John",
            "age": 30,
            "isEmployed": true
        }
        """
        let jsonData = jsonString.data(using: .utf8)!

        let task = JSONParsingTask(jsonData: jsonData)

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()

        // Then
        guard let parsedJSON = taskOutputs["parsedJSON"] as? JSONElement else {
            XCTFail("Failed to parse JSON.")
            return
        }

        if case let .object(parsedDict) = parsedJSON {
            XCTAssertEqual(parsedDict["name"], .string("John"))
            XCTAssertEqual(parsedDict["age"], .number(30))
            XCTAssertEqual(parsedDict["isEmployed"], .number(1))
        } else {
            XCTFail("Parsed JSON is not an object.")
        }
    }

    func testParseNestedJSON() async throws {
        // Arrange: Nested JSON
        let jsonString = """
        {
            "person": {
                "name": "Jane",
                "details": {
                    "age": 25,
                    "hobbies": ["reading", "cycling"]
                }
            }
        }
        """
        let jsonData = jsonString.data(using: .utf8)!

        let task = JSONParsingTask(jsonData: jsonData)

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()

        // Then
        guard let parsedJSON = taskOutputs["parsedJSON"] as? JSONElement else {
            XCTFail("Failed to parse JSON.")
            return
        }

        // Expected structure
        let expectedJSON = JSONElement.object([
            "person": .object([
                "name": .string("Jane"),
                "details": .object([
                    "age": .number(25),
                    "hobbies": .array([
                        .string("reading"),
                        .string("cycling")
                    ])
                ])
            ])
        ])

        // Compare parsed structure with expected structure
        XCTAssertEqual(parsedJSON, expectedJSON)
    }

    func testParseArrayJSON() async throws {
        // Arrange: JSON Array
        let jsonString = """
        [
            {"id": 1, "value": "A"},
            {"id": 2, "value": "B"}
        ]
        """
        let jsonData = jsonString.data(using: .utf8)!

        let task = JSONParsingTask(jsonData: jsonData)

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()

        // Then
        guard let parsedJSON = taskOutputs["parsedJSON"] as? JSONElement else {
            XCTFail("Failed to parse JSON.")
            return
        }

        // Expected structure
        let expectedJSON = JSONElement.array([
            .object([
                "id": .number(1),
                "value": .string("A")
            ]),
            .object([
                "id": .number(2),
                "value": .string("B")
            ])
        ])

        // Compare parsed structure with expected structure
        XCTAssertEqual(parsedJSON, expectedJSON)
    }

    func testParseInvalidJSON() async throws {
        // Arrange: Invalid JSON
        let jsonString = """
        {
            "name": "Invalid JSON"
            "missingComma": true
        }
        """
        let jsonData = jsonString.data(using: .utf8)!

        let task = JSONParsingTask(jsonData: jsonData)

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        // Then
        do {
            // Attempt to execute the task
            let taskOutputs = try await unwrappedTask.execute()

            // Ensure parsing should fail by checking for parsedJSON
            if let parsedJSON = taskOutputs["parsedJSON"] as? JSONElement {
                print("Parsed JSON unexpectedly succeeded: \(parsedJSON.debugDescription)")
                XCTFail("Expected JSON parsing to fail but it succeeded.")
            }
        } catch {
            // Test passes as parsing failed
            print("Parsing failed as expected: \(error)")
        }
    }

    func testParseEmptyJSON() async throws {
        // Arrange: Empty JSON
        let jsonData = Data()

        let task = JSONParsingTask(jsonData: jsonData)

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        // Then
        do {
            // Attempt to execute the task
            let taskOutputs = try await unwrappedTask.execute()

            // Ensure parsing should fail by checking for parsedJSON
            if let parsedJSON = taskOutputs["parsedJSON"] as? JSONElement {
                print("Parsed JSON unexpectedly succeeded: \(parsedJSON.debugDescription)")
                XCTFail("Expected JSON parsing to fail but it succeeded.")
            }
        } catch {
            // Test passes as parsing failed
            print("Parsing failed as expected: \(error)")
        }
    }
}
