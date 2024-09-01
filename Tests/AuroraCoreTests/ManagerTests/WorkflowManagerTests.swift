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
        let workflow = MockWorkflow(name: "Test Workflow", description: "A test workflow")
        let manager = WorkflowManager(workflow: workflow)

        // When
        let workflowState = manager.getWorkflowState()

        // Then
        XCTAssertTrue(workflowState.isNotStarted, "Initial workflow state should be 'Not Started'.")
    }

    func testStartWorkflowWithTasks() {
        // Given
        let workflow = MockWorkflow(name: "Test Workflow", description: "A test workflow")
        let task1 = MockWorkflowTask(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])
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
        let workflow = MockWorkflow(name: "Test Workflow", description: "A test workflow")
        let task1 = MockWorkflowTask(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task", inputs: ["requiredInput": nil], hasRequiredInputsValue: false) // Missing required input
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
        let workflow = MockWorkflow(name: "Test Workflow", description: "A test workflow")
        let task1 = MockWorkflowTask(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task", inputs: ["input2": nil], hasRequiredInputsValue: false) // This will trigger failure
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
        let workflow = MockWorkflow(name: "Empty Workflow", description: "A workflow with no tasks")
        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.start()

        // Then
        XCTAssertTrue(manager.getWorkflowState().isCompleted, "Empty workflows should be marked as completed.")
    }

    func testMarkWorkflowCompleteAfterAllTasks() {
        // Given
        let workflow = MockWorkflow(name: "Test Workflow", description: "A test workflow")
        let task1 = MockWorkflowTask(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])
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
        let task1 = MockWorkflowTask(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])
        task1.markCompleted()
        task2.markCompleted()

        let workflow = MockWorkflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1, task2])
        workflow.tryMarkCompleted()

        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.start() // This should now trigger the guard in `start()`

        // Then
        XCTAssertTrue(manager.getWorkflowState().isCompleted, "Workflow should already be marked as completed, and no task should be executed.")
    }

    func testExecuteCurrentTaskDoesNotRunIfWorkflowCompleted() {
        // Given
        let task1 = MockWorkflowTask(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])
        task1.markCompleted()
        task2.markCompleted()

        let workflow = MockWorkflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1, task2])
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
        let task1 = MockWorkflowTask(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let workflow = MockWorkflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1])
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
        let task = MockWorkflowTask(name: "Test Task", description: "Task with retries", retryCount: 0, maxRetries: 3, hasRequiredInputsValue: true)
        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task])
        let manager = WorkflowManager(workflow: workflow)

        // Simulate the task failing
        task.status = .failed
        task.incrementRetryCount()
        workflow.updateTask(task, at: 0)

        // When
        manager.evaluateState()

        // Then
        let updatedTask = manager.getWorkflow().tasks.first!
        XCTAssertEqual(updatedTask.retryCount, 1, "The task should have attempted 1 retry.")
        XCTAssertTrue(manager.getWorkflowState().isInProgress, "The workflow should still be in progress due to retries.")
    }

    // Test task failure without retries, ensuring workflow stops
    func testHandleTaskFailureNoRetries() {
        // Given
        let task = MockWorkflowTask(name: "Test Task", description: "Task without retries", inputs: ["input1": "value1"], maxRetries: 0)
        let workflow = MockWorkflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task])
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
        let task = MockWorkflowTask(name: "Mock Task", description: "A mock task", status: .completed)
        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task])
        workflow.tryMarkCompleted() // Manually mark workflow as completed
        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.stopWorkflow()  // First stop call

        // Simulate a second stop
        manager.stopWorkflow()  // Second stop call

        // Then
        XCTAssertTrue(manager.getWorkflowState().isCompleted, "The workflow should remain completed after a second stop call.")
    }

    // Test case for the notStarted state
    func testEvaluateStateWhenNotStarted() {
        // Given
        let task1 = MockWorkflowTask(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])

        let workflow = MockWorkflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1, task2])
        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.evaluateState()

        // Then
        XCTAssertEqual(manager.getWorkflowState(), .notStarted, "Workflow should remain in the not started state if no tasks have been executed.")
    }

    func testEvaluateStateWhenAllTasksCompleted() {
        // Given
        let task1 = MockWorkflowTask(name: "Task 1", description: "First task", status: .completed)
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task", status: .completed)
        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1, task2])
        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.evaluateState()

        // Then
        XCTAssertTrue(manager.getWorkflowState().isCompleted, "Workflow should be marked as completed when all tasks are completed.")
    }

    func testEvaluateStateWhenTaskFailedWithNoRetries() {
        // Given
        let task1 = MockWorkflowTask(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task", inputs: ["input2": "value2"], maxRetries: 0)
        task1.markCompleted()
        task2.markFailed()

        let workflow = MockWorkflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1, task2])
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
        let task1 = MockWorkflowTask(name: "Task 1", description: "First task", inputs: ["input1": "value1"])
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task", inputs: ["input2": "value2"])
        task1.markInProgress()

        let workflow = MockWorkflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1, task2])
        let manager = WorkflowManager(workflow: workflow)

        // When
        manager.evaluateState()

        // Then
        XCTAssertEqual(manager.getWorkflowState(), .inProgress, "Workflow should be in progress when tasks are pending or in progress.")
    }

    func testEvaluateStateWhenStopped() {
        // Given
        let task1 = MockWorkflowTask(name: "Task 1", description: "First task")
        let task2 = MockWorkflowTask(name: "Task 2", description: "Second task")
        let workflow = MockWorkflow(name: "Test Workflow", description: "This is a test workflow", tasks: [task1, task2])
        let manager = WorkflowManager(workflow: workflow)

        // Manually set the workflow state to simulate that it has started
        workflow.setState(.inProgress)

        // When
        manager.stopWorkflow() // Manually stop the workflow
        manager.evaluateState()

        // Then
        XCTAssertTrue(manager.getWorkflowState().isStopped, "Workflow should remain stopped after evaluateState() is called.")
    }
}

