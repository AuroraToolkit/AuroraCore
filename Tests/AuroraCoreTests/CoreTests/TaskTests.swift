//
//  TaskTests.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/24/24.
//

import XCTest
@testable import AuroraCore

final class TaskTests: XCTestCase {

    func testTaskInitialization() {
        // Given
        let task = Task(name: "Test Task", description: "This is a test task")

        // Then
        XCTAssertEqual(task.name, "Test Task")
        XCTAssertEqual(task.description, "This is a test task")
        XCTAssertEqual(task.status, .pending)
        XCTAssertNotNil(task.creationDate)
        XCTAssertNil(task.completionDate)
    }

    func testMarkTaskCompleted() {
        // Given
        var task = Task(name: "Test Task", description: "This is a test task")

        // When
        task.markCompleted()

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
}
