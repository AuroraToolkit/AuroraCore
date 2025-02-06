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
        
        let workflow = Workflow(name: "Reporting Workflow", description: "Workflow to test reporting") {
            task1
            taskGroup
        }

        let report = await workflow.generateReport()
        
        XCTAssertEqual(report.id, workflow.id)
        XCTAssertEqual(report.name, "Reporting Workflow")
        XCTAssertEqual(report.description, "Workflow to test reporting")
        // Since the workflow hasn't executed, the state should be .notStarted.
        XCTAssertEqual(report.state, .notStarted)
        XCTAssertNil(report.executionTime)
        XCTAssertEqual(report.outputs?.keys, workflow.outputs.keys)
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
        let workflow = Workflow(name: "Reporting Workflow", description: "Workflow to test reporting") {
            Workflow.TaskGroup(name: "Group Test", description: "A test task group", mode: .sequential) {
                Workflow.Task(name: "Task 1", description: "First task") { _ in
                    return ["result": "Done"]
                }
                Workflow.Task(name: "Task 2", description: "Second task") { _ in
                    return ["result": "Done"]
                }
            }
        }

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
}
