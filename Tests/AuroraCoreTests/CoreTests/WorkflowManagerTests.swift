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
        XCTAssertTrue(workflowState.isNotStarted, "Initial workflow state should be 'Not Started'.")
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

        // Then
        XCTAssertTrue(manager.getWorkflowState().isCompleted, "Workflow should be in the completed state.")
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

        // Then
        XCTAssertTrue(manager.getWorkflowState().isFailed, "Workflow should fail due to missing required inputs.")
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

        // Then
        XCTAssertTrue(manager.getWorkflowState().isFailed, "Workflow should not complete due to task failure.")
    }

    func testEmptyWorkflow() {
        // Given
        let workflow = Workflow(name: "Empty Workflow", description: "A workflow with no tasks")
        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.start()

        // Then
        XCTAssertTrue(manager.getWorkflowState().isCompleted, "Empty workflows should be marked as completed.")
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
        XCTAssertTrue(manager.getWorkflowState().isCompleted, "Workflow should be marked as completed after all tasks.")
    }

    func testWorkflowAlreadyCompleted() {
        // Given
        var task1 = Task(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        var task2 = Task(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])
        task1.markCompleted()
        task2.markCompleted()

        var workflow = Workflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1, task2])
        workflow.tryMarkCompleted()

        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.start() // This should now trigger the guard in `start()`

        // Then
        XCTAssertTrue(manager.getWorkflowState().isCompleted, "Workflow should already be marked as completed, and no task should be executed.")
    }

    func testExecuteCurrentTaskDoesNotRunIfWorkflowCompleted() {
        // Given
        var task1 = Task(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        var task2 = Task(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])
        task1.markCompleted()
        task2.markCompleted()

        var workflow = Workflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1, task2])
        workflow.tryMarkCompleted()

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

    // Test task failure with retries
    func testHandleTaskFailureWithRetries() {
        // Given
        let task = Task(name: "Test Task", description: "Task with retries", inputs: ["input1": "value1"], maxRetries: 3)
        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task])
        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.start() // Start the workflow
        manager.handleTaskFailure(for: task) // Simulate task failure
        manager.evaluateState()

        // Then
        let updatedTask = manager.getWorkflow().tasks.first!
        XCTAssertEqual(updatedTask.retryCount, 1, "The task should have attempted 1 retry.")
        XCTAssertTrue(manager.getWorkflowState().isInProgress, "The workflow should still be in progress due to retries.")
    }

    // Test task failure without retries, ensuring workflow stops
    func testHandleTaskFailureNoRetries() {
        // Given
        var task = Task(name: "Test Task", description: "Task without retries", inputs: ["input1": "value1"], maxRetries: 0)
        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task])
        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.start()

        // Simulate task failure
        task.markFailed()
        manager.handleTaskFailure(for: task)

        // Then
        let updatedTask = manager.getWorkflow().tasks.first!
        XCTAssertEqual(updatedTask.status, .failed, "The task should be marked as failed.")

        // Check that the workflow is in the failed state
        XCTAssertTrue(manager.getWorkflowState().isFailed, "The workflow should be in the failed state.")
    }

    // Test stopping a workflow that is already completed
    func testStopWorkflowAlreadyCompleted() {
        // Given
        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow", tasks: [])
        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.stopWorkflow()  // First stop call

        // Simulate a second stop
        manager.stopWorkflow()  // Second stop call

        let workflowState = manager.getWorkflowState()

        // Then
        if case .completed = workflowState {
            XCTAssertTrue(true)
        } else {
            XCTFail("The workflow should remain completed after a second stop call, not \(workflowState).")
        }
    }

    // Test case for the notStarted state
    func testEvaluateStateWhenNotStarted() {
        // Given
        let task1 = Task(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = Task(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])

        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1, task2])
        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.evaluateState()

        // Then
        XCTAssertEqual(manager.getWorkflowState(), .notStarted, "Workflow should remain in the not started state if no tasks have been executed.")
    }

    func testEvaluateStateWhenAllTasksCompleted() {
        // Given
        var task1 = Task(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        var task2 = Task(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])
        task1.markCompleted()
        task2.markCompleted()

        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1, task2])
        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.evaluateState()

        // Then
        XCTAssertEqual(manager.getWorkflowState(), .completed(Date()), "Workflow should be marked as completed when all tasks are completed.")
    }

    func testEvaluateStateWhenTaskFailedWithNoRetries() {
        // Given
        var task1 = Task(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        var task2 = Task(name: "Task 2", description: "Second task", inputs: ["input2": "value2"], maxRetries: 0)
        task1.markCompleted()
        task2.markFailed()

        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1, task2])
        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.evaluateState()

        // Then
        if case .failed(_, _) = manager.getWorkflowState() {
            XCTAssertTrue(true, "Workflow should be marked as failed when a task has no retries left.")
        } else {
            XCTFail("Workflow should be in the failed state.")
        }
    }

    func testEvaluateStateWhenInProgress() {
        // Given
        var task1 = Task(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = Task(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])
        task1.markInProgress()

        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1, task2])
        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.evaluateState()

        // Then
        XCTAssertEqual(manager.getWorkflowState(), .inProgress, "Workflow should be in progress when tasks are pending or in progress.")
    }

    func testEvaluateStateWhenStopped() {
        // Given
        let task1 = Task(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = Task(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])

        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1, task2])
        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.stopWorkflow() // Manually stop the workflow
        manager.evaluateState()

        // Then
        if case .stopped = manager.getWorkflowState() {
            XCTAssertTrue(true, "Workflow should remain stopped if it has been manually stopped.")
        } else {
            XCTFail("Workflow should remain in the stopped state.")
        }
    }
}

