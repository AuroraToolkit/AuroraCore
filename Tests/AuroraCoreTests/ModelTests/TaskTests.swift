//
//  TaskTests.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/24/24.
//

import XCTest
@testable import AuroraCore

final class TaskTests: XCTestCase {

    func testTaskInitializationWithInputs() {
        // Given
        let task = WorkflowTask(name: "Test Task", description: "This is a test task", inputs: ["input1": "value1", "input2": nil])

        // Then
        XCTAssertEqual(task.name, "Test Task")
        XCTAssertEqual(task.description, "This is a test task")
        XCTAssertEqual(task.inputs.count, 2)
        XCTAssertEqual(task.inputs["input1"] as? String, "value1")
        XCTAssertNil(task.inputs["input2?"] as Any?)
    }

    func testTaskInitializationWithoutInputs() {
        // Given
        let task = WorkflowTask(name: "Task Without Inputs", description: "This is a task with no inputs.")

        // Then
        XCTAssertEqual(task.name, "Task Without Inputs")
        XCTAssertEqual(task.description, "This is a task with no inputs.")
        XCTAssertTrue(task.inputs.isEmpty, "The inputs should be empty for a task without inputs.")
        XCTAssertEqual(task.status, .pending)
        XCTAssertNotNil(task.creationDate)
        XCTAssertNil(task.completionDate)
    }

    func testMarkTaskCompleted() {
        // Given
        let task = WorkflowTask(name: "Test Task", description: "This is a test task")

        // When
        task.markCompleted()

        // Then
        XCTAssertEqual(task.status, .completed)
        XCTAssertNotNil(task.completionDate)
    }

    func testMarkTaskInProgress() {
        // Given
        let task = WorkflowTask(name: "Test Task", description: "This is a test task")

        // When
        task.markInProgress()

        // Then
        XCTAssertEqual(task.status, .inProgress)
    }

    func testMarkTaskFailed() {
        // Given
        let task = WorkflowTask(name: "Test Task", description: "This is a test task")

        // When
        task.markFailed()

        // Then
        XCTAssertEqual(task.status, .failed)
    }

    func testResetTask() {
        // Given
        let task = WorkflowTask(name: "Test Task", description: "This is a test task")
        task.markCompleted()

        // When
        task.resetTask()

        // Then
        XCTAssertEqual(task.status, .pending)
        XCTAssertNil(task.completionDate)
    }

    func testHasRequiredInputsTrue() {
        // Given
        let task = WorkflowTask(name: "Test Task", description: "This is a test task")

        // When
        let hasRequiredInputs = task.hasRequiredInputs()

        // Then
        XCTAssertTrue(hasRequiredInputs, "Task should have all required inputs.")
    }

    func testHasRequiredInputsFalse() {
        // Given
        let task = WorkflowTask(name: "Test Task", description: "This is a test task", inputs: ["input": nil])

        // When
        let hasRequiredInputs = task.hasRequiredInputs()

        // Then
        XCTAssertFalse(hasRequiredInputs, "Task should not have all required inputs when one is nil.")
    }

    func testHasOptionalInputs() {
        // Given
        let task = WorkflowTask(name: "Test Task", description: "This is a test task", inputs: ["optionalInput?": nil])

        // When
        let hasRequiredInputs = task.hasRequiredInputs()

        // Then
        XCTAssertTrue(hasRequiredInputs, "Task should pass input validation since optional input is nil and required input is present.")
    }

    func testTaskExecutesInlineLogicSuccessfully() async throws {
        // Given
        let task = WorkflowTask(
            name: "Inline Logic Task",
            description: "A task with inline execution logic"
        ) { inputs in
            guard let inputValue = inputs["key"] as? String else {
                throw NSError(domain: "WorkflowTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing required input."])
            }
            return ["result": "\(inputValue) processed"]
        }
        task.inputs = ["key": "Test value"]

        // When
        let outputs = try await task.execute()

        // Then
        XCTAssertEqual(outputs["result"] as? String, "Test value processed", "Task should correctly process input and return expected outputs.")
    }

    func testTaskFailsWhenInlineLogicThrows() async throws {
        // Given
        let task = WorkflowTask(
            name: "Failing Task",
            description: "A task that always throws an error"
        ) { _ in
            throw NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Execution failed"])
        }

        // When
        do {
            _ = try await task.execute()
            XCTFail("Task execution should have thrown an error.")
        } catch {
            // Then
            XCTAssertEqual(error.localizedDescription, "Execution failed", "The error message should match the thrown error.")
        }
    }
}
