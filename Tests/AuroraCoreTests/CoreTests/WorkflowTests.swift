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

    func testSequentialTaskExecution() {
        // Given
        var workflow = Workflow(name: "Sequential Workflow", description: "This is a sequential workflow")

        var task1 = Task(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        var task2 = Task(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])

        workflow.addTask(task1)
        workflow.addTask(task2)

        // When
        workflow.start()

        // Then
        XCTAssertEqual(workflow.tasks[0].status, .completed, "Task 1 should be completed after execution.")
        XCTAssertEqual(workflow.tasks[1].status, .completed, "Task 2 should be completed after execution.")
        XCTAssertNotNil(workflow.completionDate, "Workflow should be completed once all tasks are executed.")
    }

    func testWorkflowStopsOnTaskFailure() {
        // Given
        var workflow = Workflow(name: "Failure Workflow", description: "This workflow will stop on failure")

        var task1 = Task(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        var task2 = Task(name: "Task 2", description: "Second task", inputs: ["input2": nil]) // This will fail due to nil input

        workflow.addTask(task1)
        workflow.addTask(task2)

        // When
        workflow.start()

        // Then
        XCTAssertEqual(workflow.tasks[0].status, .completed, "Task 1 should be completed successfully.")
        XCTAssertEqual(workflow.tasks[1].status, .failed, "Task 2 should have failed due to missing required input.")
        XCTAssertNil(workflow.completionDate, "Workflow should not be marked as completed if a task fails.")
    }

    func testResetAfterFailure() {
        // Given
        var workflow = Workflow(name: "Reset Workflow", description: "Workflow will reset after failure")

        var task1 = Task(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        var task2 = Task(name: "Task 2", description: "Second task", inputs: ["input2": nil]) // This will fail due to nil input

        workflow.addTask(task1)
        workflow.addTask(task2)

        // When
        workflow.start()
        workflow.resetWorkflow()

        // Then
        XCTAssertEqual(workflow.tasks[0].status, .pending, "Task 1 should be reset to pending.")
        XCTAssertEqual(workflow.tasks[1].status, .pending, "Task 2 should be reset to pending.")
        XCTAssertNil(workflow.completionDate, "Workflow should have no completion date after reset.")
    }
}
