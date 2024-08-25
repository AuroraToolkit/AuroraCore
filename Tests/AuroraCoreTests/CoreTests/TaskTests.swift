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
        let task = Task(name: "Test Task", description: "This is a test task", inputs: ["input1": "value1", "input2": nil])

        // Then
        XCTAssertEqual(task.name, "Test Task")
        XCTAssertEqual(task.description, "This is a test task")
        XCTAssertEqual(task.inputs.count, 2)
        XCTAssertEqual(task.inputs["input1"] as? String, "value1")
        XCTAssertNil(task.inputs["input2?"] as Any?)
    }

    func testTaskInitializationWithoutInputs() {
        // Given
        let task = Task(name: "Task Without Inputs", description: "This is a task with no inputs.")

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
        var task = Task(name: "Test Task", description: "This is a test task")

        // When
        task.markCompleted(withOutputs: [:])

        // Then
        XCTAssertEqual(task.status, .completed)
        XCTAssertNotNil(task.completionDate)
    }

    func testMarkTaskInProgress() {
        // Given
        var task = Task(name: "Test Task", description: "This is a test task")

        // When
        task.markInProgress()

        // Then
        XCTAssertEqual(task.status, .inProgress)
    }

    func testMarkTaskFailed() {
        // Given
        var task = Task(name: "Test Task", description: "This is a test task")

        // When
        task.markFailed()

        // Then
        XCTAssertEqual(task.status, .failed)
    }

    func testResetTask() {
        // Given
        var task = Task(name: "Test Task", description: "This is a test task")
        task.markCompleted()

        // When
        task.resetTask()

        // Then
        XCTAssertEqual(task.status, .pending)
        XCTAssertNil(task.completionDate)
    }

    func testHasRequiredInputsTrue() {
        // Given
        let task = Task(name: "Test Task", description: "This is a test task")

        // When
        let hasRequiredInputs = task.hasRequiredInputs()

        // Then
        XCTAssertTrue(hasRequiredInputs, "Task should have all required inputs.")
    }

    func testHasRequiredInputsFalse() {
        // Given
        let task = Task(name: "Test Task", description: "This is a test task", inputs: ["input": nil])

        // When
        let hasRequiredInputs = task.hasRequiredInputs()

        // Then
        XCTAssertFalse(hasRequiredInputs, "Task should not have all required inputs when one is nil.")
    }

    func testHasOptionalInputs() {
        // Given
        let task = Task(name: "Test Task", description: "This is a test task", inputs: ["optionalInput?": nil])

        // When
        let hasRequiredInputs = task.hasRequiredInputs()

        // Then
        XCTAssertTrue(hasRequiredInputs, "Task should pass input validation since optional input is nil and required input is present.")
    }
}
