//
//  WorkflowTests.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/14/24.
//

import XCTest
@testable import AuroraCore

final class WorkflowTests: XCTestCase {

    func testWorkflowWithTasks() {
        let workflow = Workflow(name: "Test Workflow", description: "This workflow has tasks.") {
            Workflow.Task(name: "Task 1", description: "First task")
            Workflow.Task(name: "Task 2", description: "Second task")
        }

        XCTAssertEqual(workflow.componentsManager.components.count, 2, "Workflow should have two components.")

        guard case let .task(task1) = workflow.componentsManager.components[0] else {
            XCTFail("First component should be a task.")
            return
        }

        XCTAssertEqual(task1.name, "Task 1")
        XCTAssertEqual(task1.description, "First task")

        guard case let .task(task2) = workflow.componentsManager.components[1] else {
            XCTFail("Second component should be a task.")
            return
        }

        XCTAssertEqual(task2.name, "Task 2")
        XCTAssertEqual(task2.description, "Second task")
    }

    func testWorkflowWithTaskGroup() {
        let workflow = Workflow(name: "Grouped Workflow", description: "Workflow with a task group.") {
            Workflow.TaskGroup(name: "Group 1") {
                Workflow.Task(name: "Task 1", description: "First task")
                Workflow.Task(name: "Task 2", description: "Second task")
            }
        }

        XCTAssertEqual(workflow.componentsManager.components.count, 1, "Workflow should have one component (a task group).")

        guard case let .taskGroup(taskGroup) = workflow.componentsManager.components.first else {
            XCTFail("First component should be a task group.")
            return
        }

        XCTAssertEqual(taskGroup.name, "Group 1")
        XCTAssertEqual(taskGroup.tasks.count, 2, "Task group should contain two tasks.")

        XCTAssertEqual(taskGroup.tasks[0].name, "Task 1")
        XCTAssertEqual(taskGroup.tasks[0].description, "First task")

        XCTAssertEqual(taskGroup.tasks[1].name, "Task 2")
        XCTAssertEqual(taskGroup.tasks[1].description, "Second task")
    }

    func testEmptyWorkflow() {
        let workflow = Workflow(name: "Empty Workflow", description: "This workflow has no tasks.") { }
        XCTAssertTrue(workflow.componentsManager.components.isEmpty, "Workflow should have no components.")
    }

    func testWorkflowExecutionWithTasks() async throws {
        let workflow = Workflow(name: "Executable Workflow", description: "Workflow executes tasks.") {
            Workflow.Task(name: "Task 1") { _ in
                print("Executing Task 1")
                return ["result": "Task 1 complete"]
            }
            Workflow.Task(name: "Task 2", inputs: ["result": "Task 1 complete"]) { inputs in
                print("Executing Task 2")
                guard let result = inputs["result"] as? String else { return [:] }
                return ["output": "\(result), and Task 2 complete"]
            }
        }

        var executableWorkflow = workflow
        await executableWorkflow.start()

        let state = await executableWorkflow.state
        XCTAssertEqual(state, .completed, "Workflow should complete successfully.")
    }

    func testWorkflowExecutionWithTaskGroupSequential() async throws {
        let workflow = Workflow(name: "Sequential Task Group", description: "Executes tasks sequentially.") {
            Workflow.TaskGroup(name: "Group 1", description: "Sequential tasks") {
                Workflow.Task(name: "Task 1") { _ in
                    print("Executing Task 1")
                    return ["result": "Task 1 complete"]
                }
                Workflow.Task(name: "Task 2") { _ in
                    print("Executing Task 2")
                    return ["result": "Task 2 complete"]
                }
            }
        }

        var executableWorkflow = workflow
        await executableWorkflow.start()

        let state = await executableWorkflow.state
        XCTAssertEqual(state, .completed, "Workflow should complete successfully.")
    }

    func testWorkflowExecutionWithTaskGroupParallel() async throws {
        let workflow = Workflow(name: "Parallel Task Group", description: "Executes tasks in parallel.") {
            Workflow.TaskGroup(name: "Group 1", description: "Parallel tasks", mode: .parallel) {
                Workflow.Task(name: "Task 1") { _ in
                    try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate 1s delay
                    print("Executing Task 1")
                    return ["result": "Task 1 complete"]
                }
                Workflow.Task(name: "Task 2") { _ in
                    print("Executing Task 2")
                    return ["result": "Task 2 complete"]
                }
            }
        }

        var executableWorkflow = workflow
        await executableWorkflow.start()

        let state = await executableWorkflow.state
        XCTAssertEqual(state, .completed, "Workflow should complete successfully.")
    }

    func testWorkflowExecutionFailure() async throws {
        let workflow = Workflow(name: "Failing Workflow", description: "A workflow with a failing task.") {
            Workflow.Task(name: "Failing Task") { _ in
                print("Executing Failing Task")
                throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Task failed"])
            }
        }

        var executableWorkflow = workflow
        await executableWorkflow.start()

        let state = await executableWorkflow.state
        XCTAssertEqual(state, .failed, "Workflow should fail if a task throws an error.")
    }

    func testTaskGroupSequentialFailure() async throws {
        let workflow = Workflow(name: "Sequential Task Group Failure", description: "A task fails in sequential group.") {
            Workflow.TaskGroup(name: "Group 1", description: "Sequential tasks") {
                Workflow.Task(name: "Task 1") { _ in
                    print("Executing Task 1")
                    return ["result": "Task 1 complete"]
                }
                Workflow.Task(name: "Task 2") { _ in
                    print("Executing Task 2")
                    throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Task 2 failed"])
                }
                Workflow.Task(name: "Task 3") { _ in
                    XCTFail("Task 3 should not execute after Task 2 failure.")
                    return [:]
                }
            }
        }

        var executableWorkflow = workflow
        await executableWorkflow.start()

        let state = await executableWorkflow.state
        XCTAssertEqual(state, .failed, "Workflow should fail if a task in a sequential group throws an error.")
    }

    func testTaskGroupParallelFailure() async throws {
        let workflow = Workflow(name: "Parallel Task Group Failure", description: "A task fails in parallel group.") {
            Workflow.TaskGroup(name: "Group 1", description: "Parallel tasks", mode: .parallel) {
                Workflow.Task(name: "Task 1") { _ in
                    try await Task.sleep(nanoseconds: 500_000_000) // Simulate delay
                    print("Executing Task 1")
                    throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Task 1 failed"])
                }
                Workflow.Task(name: "Task 2") { _ in
                    try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate longer delay
                    XCTFail("Task 2 should be canceled after Task 1 failure.")
                    return [:]
                }
            }
        }

        var executableWorkflow = workflow
        await executableWorkflow.start()

        let state = await executableWorkflow.state
        XCTAssertEqual(state, .failed, "Workflow should fail if a task in a parallel group throws an error.")
    }

    func testWorkflowCancelation() async throws {
        let workflow = Workflow(name: "Cancelable Workflow", description: "Workflow that can be canceled.") {
            Workflow.Task(name: "Task 1") { _ in
                print("Executing Task 1")
                try await Task.sleep(nanoseconds: 5_000_000_000) // Simulate a 5s delay
                return ["result": "Task 1 complete"]
            }
            Workflow.Task(name: "Task 2") { _ in
                XCTFail("Task 2 should not execute after cancelation.")
                return [:]
            }
        }

        var cancelableWorkflow = workflow

        Task {
            try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate a delay before canceling
            print("Canceling workflow...")
            await cancelableWorkflow.cancel()
        }

        await cancelableWorkflow.start()

        let state = await cancelableWorkflow.state
        XCTAssertEqual(state, .canceled, "Workflow should be in the canceled state.")
    }

    func testWorkflowPauseAndResume() async throws {
        let workflow = Workflow(name: "Pausable Workflow", description: "Workflow that can be paused and resumed.") {
            Workflow.Task(name: "Task 1") { _ in
                print("Executing Task 1")
                try await Task.sleep(nanoseconds: 500_000_000) // Simulate delay
                return ["result": "Task 1 complete"]
            }
            Workflow.Task(name: "Task 2") { _ in
                print("Executing Task 2")
                return ["result": "Task 2 complete"]
            }
        }

        var pausableWorkflow = workflow
        Task {
            try await Task.sleep(nanoseconds: 300_000_000) // Pause after 300ms
            await pausableWorkflow.pause()
            try await Task.sleep(nanoseconds: 700_000_000) // Resume after an additional 700ms
            await pausableWorkflow.resume()
        }

        await pausableWorkflow.start()

        let state = await pausableWorkflow.state
        XCTAssertEqual(state, .completed, "Workflow should complete successfully after pausing and resuming.")
    }

    func testCancelWhilePaused() async throws {
        let workflow = Workflow(name: "Pause and Cancel Workflow", description: "Workflow that is paused and then canceled.") {
            Workflow.Task(name: "Task 1") { _ in
                print("Executing Task 1")
                try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate delay
                return ["result": "Task 1 complete"]
            }
            Workflow.Task(name: "Task 2") { _ in
                XCTFail("Task 2 should not execute after cancelation.")
                return [:]
            }
        }

        var workflowInstance = workflow
        Task {
            try await Task.sleep(nanoseconds: 500_000_000) // Pause after 500ms
            await workflowInstance.pause()
            try await Task.sleep(nanoseconds: 500_000_000) // Cancel while paused
            await workflowInstance.cancel()
        }

        await workflowInstance.start()

        let state = await workflowInstance.state
        XCTAssertEqual(state, .canceled, "Workflow should be in the canceled state.")
    }

    func testWorkflowTaskTimeout() async throws {
        let workflow = Workflow(name: "Timeout Workflow", description: "Workflow with a task timeout.") {
            Workflow.Task(name: "Long Task") { _ in
                print("Executing Long Task")
                try await Task.sleep(nanoseconds: 3_000_000_000) // Simulate a 3s delay
                return ["result": "Long Task complete"]
            }
        }

        var timeoutWorkflow = workflow
        let timeoutDuration: UInt64 = 1_000_000_000 // 1 second

        Task {
            try await Task.sleep(nanoseconds: timeoutDuration)
            await timeoutWorkflow.cancel()
        }

        await timeoutWorkflow.start()

        let state = await timeoutWorkflow.state
        XCTAssertEqual(state, .canceled, "Workflow should be in the canceled state due to timeout.")
    }
}
