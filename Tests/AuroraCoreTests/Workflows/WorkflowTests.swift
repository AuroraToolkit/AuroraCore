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

        XCTAssertEqual(workflow.components.count, 2, "Workflow should have two components.")

        guard case let .task(task1) = workflow.components[0] else {
            XCTFail("First component should be a task.")
            return
        }

        XCTAssertEqual(task1.name, "Task 1")
        XCTAssertEqual(task1.description, "First task")

        guard case let .task(task2) = workflow.components[1] else {
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

        XCTAssertEqual(workflow.components.count, 1, "Workflow should have one component (a task group).")

        guard case let .taskGroup(taskGroup) = workflow.components.first else {
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
        XCTAssertTrue(workflow.components.isEmpty, "Workflow should have no components.")
    }
}
