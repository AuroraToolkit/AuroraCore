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
        XCTAssertEqual(workflow.state, .notStarted, "The workflow should be not started when initialized.")
    }

    func testAddTaskToWorkflow() {
        // Given
        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow")
        let task = MockWorkflowTask(name: "Test Task", description: "This is a test task")

        // When
        workflow.addTask(task)

        // Then
        XCTAssertEqual(workflow.tasks.count, 1)
        XCTAssertEqual(workflow.tasks.first?.name, "Test Task")
    }

    func testMarkWorkflowCompleted() {
        // Given
        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow")
        let task1 = MockWorkflowTask(name: "Task 1", description: "First task")
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task")
        task1.markCompleted()
        task2.markFailed()

        // Add tasks to workflow
        workflow.addTask(task1)
        workflow.addTask(task2)

        // When
        workflow.tryMarkCompleted()

        // Then
        if case .completed(_) = workflow.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Workflow should be in the completed state.")
        }
    }

    func testMarkWorkflowNotCompletedIfActiveTasksExist() {
        // Given
        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow")
        let task1 = MockWorkflowTask(name: "Task 1", description: "First task")
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task")
        task1.markCompleted()

        // Add tasks to workflow
        workflow.addTask(task1)
        workflow.addTask(task2)

        // When
        workflow.tryMarkCompleted()

        // Then
        XCTAssertEqual(workflow.state, .notStarted, "Workflow should not be marked as completed if there are active tasks.")
    }

    func testResetWorkflow() {
        // Given
        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow")
        let task1 = MockWorkflowTask(name: "Task 1", description: "First task")
        task1.markCompleted()

        // Add tasks to workflow and mark workflow completed
        workflow.addTask(task1)
        workflow.tryMarkCompleted()

        // When
        workflow.resetWorkflow()

        // Then
        XCTAssertEqual(workflow.tasks.first?.status, .pending)
        XCTAssertEqual(workflow.state, .notStarted, "Workflow should be reset to not started after a reset.")
    }

    func testCompletedTasks() {
        // Given
        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow")
        let task1 = MockWorkflowTask(name: "Task 1", description: "First task")
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task")
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
        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow")
        let task1 = MockWorkflowTask(name: "Task 1", description: "First task")
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task")
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

    func testSequentialTaskExecution() async {
        // Given
        let workflow = Workflow(name: "Sequential Workflow", description: "This is a sequential workflow")
        let manager = WorkflowManager(workflow: workflow)

        let task1 = MockWorkflowTask(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])

        workflow.addTask(task1)
        workflow.addTask(task2)

        // When
        await manager.start()

        // Then
        XCTAssertEqual(workflow.tasks[0].status, .completed, "Task 1 should be completed after execution.")
        XCTAssertEqual(workflow.tasks[1].status, .completed, "Task 2 should be completed after execution.")
        if case .completed = workflow.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Workflow should be in the completed state after executing all tasks.")
        }
    }

    func testWorkflowStopsOnTaskFailure() async {
        // Given
        let workflow = Workflow(name: "Failure Workflow", description: "This workflow will stop on failure")
        let manager = WorkflowManager(workflow: workflow)

        let task1 = MockWorkflowTask(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task", inputs: ["input2": nil], hasRequiredInputsValue: false) // This will fail due to nil input

        workflow.addTask(task1)
        workflow.addTask(task2)

        // When
        await manager.start()

        // Then
        XCTAssertEqual(workflow.tasks[0].status, .completed, "Task 1 should be completed successfully.")
        XCTAssertEqual(workflow.tasks[1].status, .failed, "Task 2 should have failed due to missing required input.")

        if case .failed(_, _) = workflow.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Workflow should be in the failed state.")
        }
    }

    func testResetAfterFailure() async {
        // Given
        let workflow = Workflow(name: "Reset Workflow", description: "Workflow will reset after failure")
        let manager = WorkflowManager(workflow: workflow)

        let task1 = MockWorkflowTask(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task", inputs: ["input2": nil]) // This will fail due to nil input

        workflow.addTask(task1)
        workflow.addTask(task2)

        // When
        await manager.start()
        workflow.resetWorkflow()

        // Then
        XCTAssertEqual(workflow.tasks[0].status, .pending, "Task 1 should be reset to pending.")
        XCTAssertEqual(workflow.tasks[1].status, .pending, "Task 2 should be reset to pending.")
        XCTAssertEqual(workflow.state, .notStarted, "Workflow should be reset to not started after failure and reset.")
    }
}
