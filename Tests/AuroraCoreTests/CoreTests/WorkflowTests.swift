//
//  WorkflowTests.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/24/24.
//

import XCTest
@testable import AuroraCore

final class WorkflowTests: XCTestCase {

    func testWorkflowInitialization() {
        // Given
        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow")

        // Then
        XCTAssertEqual(workflow.name, "Test Workflow")
        XCTAssertEqual(workflow.description, "This is a test workflow")
        XCTAssertEqual(workflow.tasks.count, 0)
        XCTAssertNotNil(workflow.creationDate)
        XCTAssertNil(workflow.completionDate)
    }

    func testAddTaskToWorkflow() {
        // Given
        var workflow = Workflow(name: "Test Workflow", description: "This is a test workflow")
        let task = Task(name: "Test Task", description: "This is a test task")

        // When
        workflow.addTask(task)

        // Then
        XCTAssertEqual(workflow.tasks.count, 1)
        XCTAssertEqual(workflow.tasks.first?.name, "Test Task")
    }

    func testMarkWorkflowCompleted() {
        // Given
        var workflow = Workflow(name: "Test Workflow", description: "This is a test workflow")
        var task1 = Task(name: "Task 1", description: "First task")
        var task2 = Task(name: "Task 2", description: "Second task")
        task1.markCompleted()
        task2.markFailed()

        // Add tasks to workflow
        workflow.addTask(task1)
        workflow.addTask(task2)

        // When
        workflow.markCompleted()

        // Then
        XCTAssertNotNil(workflow.completionDate)
    }

    func testMarkWorkflowNotCompletedIfActiveTasksExist() {
        // Given
        var workflow = Workflow(name: "Test Workflow", description: "This is a test workflow")
        var task1 = Task(name: "Task 1", description: "First task")
        let task2 = Task(name: "Task 2", description: "Second task")
        task1.markCompleted()

        // Add tasks to workflow
        workflow.addTask(task1)
        workflow.addTask(task2)

        // When
        workflow.markCompleted()

        // Then
        XCTAssertNil(workflow.completionDate)
    }

    func testResetWorkflow() {
        // Given
        var workflow = Workflow(name: "Test Workflow", description: "This is a test workflow")
        var task1 = Task(name: "Task 1", description: "First task")
        task1.markCompleted()

        // Add tasks to workflow and mark workflow completed
        workflow.addTask(task1)
        workflow.markCompleted()

        // When
        workflow.resetWorkflow()

        // Then
        XCTAssertEqual(workflow.tasks.first?.status, .pending)
        XCTAssertNil(workflow.completionDate)
    }

    func testCompletedTasks() {
        // Given
        var workflow = Workflow(name: "Test Workflow", description: "This is a test workflow")
        var task1 = Task(name: "Task 1", description: "First task")
        let task2 = Task(name: "Task 2", description: "Second task")
        task1.markCompleted()

        // Add tasks to workflow
        workflow.addTask(task1)
        workflow.addTask(task2)

        // When
        let completedTasks = workflow.completedTasks()

        // Then
        XCTAssertEqual(completedTasks.count, 1)
    }

    func testActiveTasks() {
        // Given
        var workflow = Workflow(name: "Test Workflow", description: "This is a test workflow")
        var task1 = Task(name: "Task 1", description: "First task")
        let task2 = Task(name: "Task 2", description: "Second task")
        task1.markCompleted()

        // Add tasks to workflow
        workflow.addTask(task1)
        workflow.addTask(task2)

        // When
        let activeTasks = workflow.activeTasks()

        // Then
        XCTAssertEqual(activeTasks.count, 1)
        XCTAssertEqual(activeTasks.first?.name, "Task 2")
    }
}
