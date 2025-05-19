//
//  WorkflowReportingTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 2/1/25.
//

import XCTest
@testable import AuroraCore

final class WorkflowReportingTests: XCTestCase {

    // Test the report generated from a single Task.
    func testTaskReport() {
        let task = Workflow.Task(name: "Test Task", description: "A simple test task", inputs: [:]) { _ in
            return ["output": "Test"]
        }

        let report = task.generateReport()

        XCTAssertEqual(report.id, task.id)
        XCTAssertEqual(report.name, "Test Task")
        XCTAssertEqual(report.description, "A simple test task")
        // Our default implementation currently returns .notStarted as state.
        XCTAssertEqual(report.state, .notStarted)
        XCTAssertNil(report.executionTime)
        XCTAssertNil(report.outputs)
        XCTAssertNil(report.error)
    }

    // Test the report generated from a TaskGroup.
    func testTaskGroupReport() {
        let task1 = Workflow.Task(name: "Task 1", description: "First task") { _ in
            return ["result": "Done"]
        }

        let task2 = Workflow.Task(name: "Task 2", description: "Second task") { _ in
            return ["result": "Done"]
        }

        let taskGroup = Workflow.TaskGroup(name: "Group Test", description: "A test task group", mode: .sequential) {
            task1
            task2
        }

        let report = taskGroup.generateReport()

        XCTAssertEqual(report.id, taskGroup.id)
        XCTAssertEqual(report.name, "Group Test")
        XCTAssertEqual(report.description, "A test task group")
        XCTAssertEqual(report.state, .notStarted)
        XCTAssertNil(report.executionTime)
        XCTAssertNil(report.outputs)
        XCTAssertNil(report.error)
    }

    // Test the overall Workflow report generation.
    func testWorkflowReportGeneration() async {
        let task1 = Workflow.Task(name: "Task 1", description: "First task") { _ in
            return ["result": "Done"]
        }

        let taskGroup = Workflow.TaskGroup(name: "Group Test", description: "A test task group", mode: .sequential) {
            task1.toComponent()
        }

        var workflow = Workflow(name: "Reporting Workflow", description: "Workflow to test reporting") {
            task1
            taskGroup
        }

        await workflow.start()

        let report = await workflow.generateReport()

        XCTAssertEqual(report.id, workflow.id)
        XCTAssertEqual(report.name, "Reporting Workflow")
        XCTAssertEqual(report.description, "Workflow to test reporting")
        XCTAssertEqual(report.state, .completed)
        XCTAssertNotEqual(report.executionTime, 0.0)
        XCTAssertEqual(report.outputs?.keys.count, 2)
        XCTAssertEqual(report.componentReports.count, 2)

        let componentReportNames = report.componentReports.map { $0.name }
        XCTAssertTrue(componentReportNames.contains("Task 1"))
        XCTAssertTrue(componentReportNames.contains("Group Test"))
    }

    func testTaskGroupChildReports() {
        // Create a TaskGroup with two tasks.
        let taskGroup = Workflow.TaskGroup(name: "Group Test", description: "A test task group", mode: .sequential) {
            Workflow.Task(name: "Task 1", description: "First task") { _ in
                return ["result": "Done"]
            }
            Workflow.Task(name: "Task 2", description: "Second task") { _ in
                return ["result": "Done"]
            }
        }

        // Generate the report for the task group.
        let report = taskGroup.generateReport()

        // Check that the report includes child reports.
        XCTAssertNotNil(report.childReports, "Child reports should not be nil.")
        XCTAssertEqual(report.childReports?.count, 2, "There should be two child reports for the tasks.")

        let childNames = report.childReports?.map { $0.name } ?? []
        XCTAssertTrue(childNames.contains("Task 1"), "Child report should contain 'Task 1'.")
        XCTAssertTrue(childNames.contains("Task 2"), "Child report should contain 'Task 2'.")
    }

    func testWorkflowNestedChildReports() async {
        // Create a workflow that contains a task group with two tasks.
        var workflow = Workflow(name: "Reporting Workflow", description: "Workflow to test reporting") {
            Workflow.TaskGroup(name: "Group Test", description: "A test task group", mode: .sequential) {
                Workflow.Task(name: "Task 1", description: "First task") { _ in
                    return ["result": "Done"]
                }
                Workflow.Task(name: "Task 2", description: "Second task") { _ in
                    return ["result": "Done"]
                }
            }
        }

        await workflow.start()

        // Generate the overall workflow report.
        let report = await workflow.generateReport()

        // Ensure the workflow report includes the task group component.
        guard let groupReport = report.componentReports.first(where: { $0.name == "Group Test" }) else {
            XCTFail("Group Test report not found.")
            return
        }

        // Verify the task group report contains child reports for its tasks.
        XCTAssertNotNil(groupReport.childReports, "Child reports for the task group should not be nil.")
        XCTAssertEqual(groupReport.childReports?.count, 2, "There should be two child reports in the task group.")

        let childNames = groupReport.childReports?.map { $0.name } ?? []
        XCTAssertTrue(childNames.contains("Task 1"), "Child reports should contain 'Task 1'.")
        XCTAssertTrue(childNames.contains("Task 2"), "Child reports should contain 'Task 2'.")
    }

    func testTaskReportAfterExecution() {
        // Create a task.
        let task = Workflow.Task(name: "Test Task", description: "A simple test task", inputs: [:]) { _ in
            return ["output": "Test"]
        }

        // Simulate execution by manually setting execution details.
        let simulatedDetails = Workflow.ExecutionDetails(
            state: .completed,
            startedAt: Date(),
            endedAt: Date(),
            executionTime: 2.5,
            outputs: ["output": "Simulated"],
            error: nil
        )
        task.updateExecutionDetails(simulatedDetails)

        // Generate the report.
        let report = task.generateReport()

        // Verify that the report contains the simulated details.
        XCTAssertEqual(report.state, .completed)
        XCTAssertEqual(report.executionTime, 2.5)
        XCTAssertEqual(report.outputs?["output"] as? String, "Simulated")
        XCTAssertNil(report.error)
    }

    func testTaskGroupReportAfterExecution() {
        // Create two tasks.
        let task1 = Workflow.Task(name: "Task 1", description: "First task") { _ in
            return ["result": "Done"]
        }
        let task2 = Workflow.Task(name: "Task 2", description: "Second task") { _ in
            return ["result": "Done"]
        }

        // Create a task group containing these tasks.
        let taskGroup = Workflow.TaskGroup(name: "Group Test", description: "A test task group", mode: .sequential) {
            task1
            task2
        }

        // Simulate execution for the task group.
        let groupSimulatedDetails = Workflow.ExecutionDetails(
            state: .completed,
            startedAt: Date(),
            endedAt: Date(),
            executionTime: 5.0,
            outputs: ["GroupResult": "Simulated Group"],
            error: nil
        )
        taskGroup.updateExecutionDetails(groupSimulatedDetails)

        // Also simulate execution for the individual tasks.
        let taskSimulatedDetails = Workflow.ExecutionDetails(
            state: .completed,
            startedAt: Date(),
            endedAt: Date(),
            executionTime: 2.0,
            outputs: ["result": "Done"],
            error: nil
        )
        task1.updateExecutionDetails(taskSimulatedDetails)
        task2.updateExecutionDetails(taskSimulatedDetails)

        // Generate the report.
        let report = taskGroup.generateReport()

        // Verify that the task group report reflects its own details and includes child reports.
        XCTAssertEqual(report.state, .completed)
        XCTAssertEqual(report.executionTime, 5.0)
        XCTAssertEqual(report.outputs?["GroupResult"] as? String, "Simulated Group")
        XCTAssertNil(report.error)
        XCTAssertNotNil(report.childReports)
        XCTAssertEqual(report.childReports?.count, 2)

        // Optionally, verify that the child reports match the simulated details.
        for child in report.childReports ?? [] {
            XCTAssertEqual(child.state, .completed)
            XCTAssertEqual(child.executionTime, 2.0)
            XCTAssertEqual(child.outputs?["result"] as? String, "Done")
        }
    }

    // Test error handling for a task that fails.
    func testTaskErrorReport() {
        let errorTask = Workflow.Task(name: "Error Task", description: "This task fails") { _ in
            throw NSError(domain: "TestError", code: 999, userInfo: [NSLocalizedDescriptionKey: "Simulated failure"])
        }

        // Simulate execution error by manually updating execution details.
        let simulatedError = NSError(domain: "TestError", code: 999, userInfo: [NSLocalizedDescriptionKey: "Simulated failure"])
        let simulatedDetails = Workflow.ExecutionDetails(
            state: .failed,
            startedAt: Date(),
            endedAt: Date(),
            executionTime: 1.0,
            outputs: [:],
            error: simulatedError
        )
        errorTask.updateExecutionDetails(simulatedDetails)

        let report = errorTask.generateReport()
        XCTAssertEqual(report.state, .failed)
        XCTAssertEqual(report.executionTime, 1.0)
        XCTAssertEqual(report.outputs?.count, 0)
        XCTAssertNotNil(report.error)
        XCTAssertEqual(report.error?.localizedDescription, "Simulated failure")
    }

    // Test that an empty workflow produces an empty report.
    func testEmptyWorkflowReport() async {
        let workflow = Workflow(name: "Empty Workflow", description: "No components") {
            // No components.
        }

        let report = await workflow.generateReport()
        XCTAssertEqual(report.componentReports.count, 0)
        XCTAssertEqual(report.outputs?.count, 0)
        // The state should be .notStarted since nothing ran.
        XCTAssertEqual(report.state, .notStarted)
        XCTAssertEqual(report.executionTime, 0.0)
    }

    // Test a parallel task group report.
    func testParallelTaskGroupReport() {
        let task1 = Workflow.Task(name: "Parallel Task 1", description: "First parallel task") { _ in
            return ["result": "First done"]
        }
        let task2 = Workflow.Task(name: "Parallel Task 2", description: "Second parallel task") { _ in
            return ["result": "Second done"]
        }

        let parallelGroup = Workflow.TaskGroup(name: "Parallel Group", description: "A parallel task group", mode: .parallel) {
            task1
            task2
        }

        // Simulate execution for the group.
        let groupDetails = Workflow.ExecutionDetails(
            state: .completed,
            startedAt: Date(),
            endedAt: Date(),
            executionTime: 3.0,
            outputs: ["groupResult": "All done"],
            error: nil
        )
        parallelGroup.updateExecutionDetails(groupDetails)

        // Simulate execution for the individual tasks.
        let taskDetails = Workflow.ExecutionDetails(
            state: .completed,
            startedAt: Date(),
            endedAt: Date(),
            executionTime: 1.5,
            outputs: ["result": "Done"],
            error: nil
        )
        task1.updateExecutionDetails(taskDetails)
        task2.updateExecutionDetails(taskDetails)

        let report = parallelGroup.generateReport()
        XCTAssertEqual(report.state, .completed)
        XCTAssertEqual(report.executionTime, 3.0)
        XCTAssertEqual(report.outputs?["groupResult"] as? String, "All done")
        XCTAssertNotNil(report.childReports)
        XCTAssertEqual(report.childReports?.count, 2)

        for child in report.childReports ?? [] {
            XCTAssertEqual(child.state, .completed)
            XCTAssertEqual(child.executionTime, 1.5)
            XCTAssertEqual(child.outputs?["result"] as? String, "Done")
        }
    }
}
