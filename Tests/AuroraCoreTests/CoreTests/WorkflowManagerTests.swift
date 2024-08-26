//
//  WorkflowManagerTests.swift
//
//
//  Created by Dan Murrell Jr on 8/25/24.
//

import XCTest
@testable import AuroraCore

final class WorkflowManagerTests: XCTestCase {

    func testWorkflowManagerInitialization() {
        // Given
        let workflow = Workflow(name: "Test Workflow", description: "A test workflow")
        let manager = WorkflowManager(workflow: workflow)

        // When
        let workflowState = manager.getWorkflowState()

        // Then
        XCTAssertEqual(workflowState, "In Progress", "Initial workflow state should be 'In Progress'.")
    }

    func testStartWorkflowWithTasks() {
        // Given
        var workflow = Workflow(name: "Test Workflow", description: "A test workflow")
        let task1 = Task(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = Task(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])
        workflow.addTask(task1)
        workflow.addTask(task2)

        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.start()
        let workflowState = manager.getWorkflowState()

        // Then
        XCTAssertEqual(workflowState, "Completed", "Workflow should complete after all tasks are processed.")
    }

    func testStartWorkflowWithMissingInputs() {
        // Given
        var workflow = Workflow(name: "Test Workflow", description: "A test workflow")
        let task1 = Task(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = Task(name: "Task 2", description: "Second task", inputs: ["requiredInput": nil]) // Missing required input
        workflow.addTask(task1)
        workflow.addTask(task2)

        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.start()
        let workflowState = manager.getWorkflowState()

        // Then
        XCTAssertEqual(workflowState, "In Progress", "Workflow should stop due to missing required inputs.")
    }

    func testHandleTaskFailure() {
        // Given
        var workflow = Workflow(name: "Test Workflow", description: "A test workflow")
        let task1 = Task(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = Task(name: "Task 2", description: "Second task", inputs: ["input2": nil]) // This will trigger failure
        workflow.addTask(task1)
        workflow.addTask(task2)

        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.start()
        let workflowState = manager.getWorkflowState()

        // Then
        XCTAssertEqual(workflowState, "In Progress", "Workflow should not complete due to task failure.")
    }

    func testEmptyWorkflow() {
        // Given
        let workflow = Workflow(name: "Empty Workflow", description: "A workflow with no tasks")
        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.start()
        let workflowState = manager.getWorkflowState()

        // Then
        XCTAssertEqual(workflowState, "In Progress", "Empty workflows should not be marked as completed.")
    }

    func testMarkWorkflowCompleteAfterAllTasks() {
        // Given
        var workflow = Workflow(name: "Test Workflow", description: "A test workflow")
        let task1 = Task(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = Task(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])
        workflow.addTask(task1)
        workflow.addTask(task2)

        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.start()

        // Then
        XCTAssertEqual(manager.getWorkflowState(), "Completed", "Workflow should be marked as completed after all tasks.")
    }

    func testWorkflowAlreadyCompleted() {
        // Given
        var task1 = Task(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        var task2 = Task(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])
        task1.markCompleted()
        task2.markCompleted()

        var workflow = Workflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1, task2])
        workflow.markCompleted()

        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.start() // This should now trigger the guard in `start()`

        // Then
        XCTAssertEqual(manager.getWorkflowState(), "Completed", "Workflow should already be marked as completed, and no task should be executed.")
        XCTAssertTrue(manager.isCompleted(), "Workflow should return true for isCompleted()")
    }

    func testExecuteCurrentTaskDoesNotRunIfWorkflowCompleted() {
        // Given
        var task1 = Task(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        var task2 = Task(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])
        task1.markCompleted()
        task2.markCompleted()

        var workflow = Workflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1, task2])
        workflow.markCompleted()

        let manager = WorkflowManager(workflow: workflow)

        // Manually invoke `executeCurrentTask` directly instead of through `start`
        // Ensure it doesn't execute since the workflow is marked completed
        let previousTaskIndex = manager.getCurrentTaskIndex()

        // When
        manager.executeCurrentTask() // This should hit the guard clause and do nothing

        // Then
        XCTAssertEqual(manager.getCurrentTaskIndex(), previousTaskIndex, "The task index should not change because the workflow is already completed.")
    }

    func testGetWorkflow() {
        // Given
        let task1 = Task(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1])
        let manager = WorkflowManager(workflow: workflow)

        // When
        let retrievedWorkflow = manager.getWorkflow()

        // Then
        XCTAssertEqual(retrievedWorkflow.name, workflow.name, "The retrieved workflow should be the same as the initialized one.")
        XCTAssertEqual(retrievedWorkflow.tasks.count, workflow.tasks.count, "The number of tasks in the retrieved workflow should match the original workflow.")
    }
}
