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

    func testMarkWorkflowInProgress() {
        // Given
        let workflow = Workflow(name: "Test Workflow", description: "This is a test workflow")

        // When
        workflow.markInProgress()

        // Then
        XCTAssertEqual(workflow.state, .inProgress, "Workflow should be in progress after calling markInProgress.")
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

    func testWorkflowWithMappings() async throws {
        // Create tasks
        let fetchTask = MockWorkflowTask(
            name: "FetchURLTask",
            description: "Fetch URL",
            inputs: [:]
        )
        fetchTask.outputs = ["data": "Mocked data"]

        let parseTask = MockWorkflowTask(
            name: "RSSParsingTask",
            description: "Parse RSS feed",
            inputs: [:]
        )
        parseTask.outputs = ["articles": ["Article 1", "Article 2"]]

        let summarizeTask = MockWorkflowTask(
            name: "SummarizeTask",
            description: "Summarize articles",
            inputs: [:]
        )
        summarizeTask.outputs = ["summary": "Mocked summary"]

        // Add tasks to workflow
        let workflow = Workflow(name: "Test Workflow", description: "Fetch, parse, and summarize articles")
        workflow.addTask(fetchTask)
        workflow.addTask(parseTask)
        workflow.addTask(summarizeTask)

        // Define mappings
        let mappings: WorkflowMappings = [
            "RSSParsingTask": [
                "data": "FetchURLTask.data"
            ],
            "SummarizeTask": [
                "articles": "RSSParsingTask.articles"
            ]
        ]

        // Initialize manager with workflow and mappings
        let manager = WorkflowManager(workflow: workflow, mappings: mappings)

        // Start the workflow
        await manager.start()

        // Validate workflow completion
        if case .completed(_) = workflow.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Workflow should be in the completed state.")
        }

        // Validate task inputs
        XCTAssertEqual(parseTask.inputs["data"] as? String, "Mocked data", "Parse task should receive 'data' from FetchURLTask.")
        XCTAssertEqual(summarizeTask.inputs["articles"] as? [String], ["Article 1", "Article 2"], "Summarize task should receive 'articles' from RSSParsingTask.")

        // Validate final outputs if needed
        XCTAssertEqual(summarizeTask.outputs["summary"] as? String, "Mocked summary", "Summarize task should produce a mocked summary.")
    }

    func testWorkflowHandlesFailureInInlineLogic() async {
        // Given
        let task1 = WorkflowTask(
            name: "Task 1",
            description: "First task"
        ) { inputs in
            return ["outputKey": "Task 1 result"]
        }

        let failingTask = WorkflowTask(
            name: "Failing Task",
            description: "Task with inline logic that fails"
        ) { inputs in
            throw NSError(domain: "WorkflowTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "Task failed during execution."])
        }

        let workflow = Workflow(name: "Failure Workflow", description: "Workflow with a failing task")
        workflow.addTask(task1)
        workflow.addTask(failingTask)

        let manager = WorkflowManager(workflow: workflow)

        // When
        await manager.start()

        // Then
        XCTAssertEqual(workflow.tasks[0].status, .completed, "Task 1 should complete successfully.")
        XCTAssertEqual(workflow.tasks[1].status, .failed, "Failing Task should be marked as failed.")
        XCTAssertTrue(manager.getWorkflowState().isFailed, "Workflow should fail due to a task failure.")
    }

    func testWorkflowFinalOutputsWithInlineLogic() async {
        // Given
        let task = WorkflowTask(
            name: "Final Task",
            description: "Task producing final outputs"
        ) { inputs in
            return ["finalKey": "finalValue"]
        }

        let workflow = Workflow(name: "Final Outputs Workflow", description: "Workflow producing final outputs")
        workflow.addTask(task)

        let manager = WorkflowManager(workflow: workflow)

        // When
        await manager.start()

        // Then
        XCTAssertEqual(manager.finalOutputs["finalKey"] as? String, "finalValue", "Final outputs should be correctly stored in the manager.")
        XCTAssertTrue(manager.getWorkflowState().isCompleted, "Workflow should complete successfully.")
    }
}
