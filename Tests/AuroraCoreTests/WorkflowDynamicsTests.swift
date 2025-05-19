//
//  WorkflowDynamicsTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 2/17/25.
//

import XCTest
@testable import AuroraCore

final class WorkflowDynamicsTests: XCTestCase {

    // Test that a Logic component evaluates, returns expected components, and updates its execution details.
    func testLogicComponentEvaluate() async throws {
        // Create an expected task to be returned.
        let expectedTask = Workflow.Task(name: "Test Task", description: "A test task") { _ in
            return ["result": "ok"]
        }
        // Create a Logic component with an evaluate block returning the expected task.
        let logicComponent = Workflow.Logic(name: "LogicTest", description: "Test logic component") {
            return [expectedTask.toComponent()]
        }

        // Evaluate the logic component.
        let components = try await logicComponent.evaluate()
        XCTAssertEqual(components.count, 1, "Logic component should return one component")

        // Check that the returned component is a task with the expected name.
        switch components.first! {
        case .task(let task):
            XCTAssertEqual(task.name, expectedTask.name)
        default:
            XCTFail("Expected a task component")
        }

        // Verify that execution details have been recorded.
        let details = logicComponent.detailsHolder.details
        XCTAssertNotNil(details, "Logic component should have execution details")
        XCTAssertEqual(details?.state, Workflow.State.completed)
        XCTAssertTrue((details?.executionTime ?? 0) > 0, "Execution time should be greater than zero")
    }

    // Test that a Trigger component waits, returns expected components, and updates its execution details.
    func testTriggerComponentWaitForTrigger() async throws {
        // Create an expected task to be returned.
        let expectedTask = Workflow.Task(name: "Test Task", description: "A test task") { _ in
            return ["result": "ok"]
        }
        // Create a Trigger component with a trigger block that simulates a short wait.
        let triggerComponent = Workflow.Trigger(name: "TriggerTest", description: "Test trigger component") {
            // Simulate waiting for a trigger condition.
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 sec
            return [expectedTask.toComponent()]
        }

        // Wait for the trigger.
        let components = try await triggerComponent.waitForTrigger()
        XCTAssertEqual(components.count, 1, "Trigger component should return one component")

        // Check that the returned component is a task with the expected name.
        switch components.first! {
        case .task(let task):
            XCTAssertEqual(task.name, expectedTask.name)
        default:
            XCTFail("Expected a task component")
        }

        // Verify that execution details have been recorded.
        let details = triggerComponent.detailsHolder.details
        XCTAssertNotNil(details, "Trigger component should have execution details")
        XCTAssertEqual(details?.state, Workflow.State.completed)
        XCTAssertTrue((details?.executionTime ?? 0) > 0, "Execution time should be greater than zero")
    }

    func testContinuousTriggerFiresExpectedNumberOfTimes() async throws {
       let threshold = 5
       let continuousTrigger = ContinuousTrigger(count: threshold)
        var workflow = Workflow(name: "Test Workflow", description: "Testing Continuous Trigger") {
            continuousTrigger.toComponent()
       }

       await workflow.start()

       XCTAssertEqual(continuousTrigger.firedCount, threshold, "Continuous trigger should fire exactly \(threshold) times before stopping.")
        XCTAssertEqual(workflow.outputs.keys.count, threshold, "Workflow should have \(threshold) outputs.")
        for i in 1...threshold {
            let key = "Counter.\(i)"
            XCTAssertEqual(workflow.outputs[key] as? String, "complete", "Workflow output for \(key) should be 'complete'")
        }
    }

    func testWorkflowCancellationWhileAsyncActive() async throws {
        let threshold = 5
        let continuousTrigger = ContinuousTrigger(count: threshold, delay: 0.2)
        var workflow = Workflow(name: "Cancellation Test Workflow", description: "Testing cancellation with active async triggers") {
            continuousTrigger.toComponent()
        }

        // Start the workflow in a separate task.
        let workflowTask = Task {
            await workflow.start()
        }

        // Wait briefly, then cancel the workflow.
        try await Task.sleep(nanoseconds: 300_000_000) // 300 ms delay
        await workflow.cancel()

        // Wait for the workflow to finish.
        await workflowTask.value

        // Assert that the workflow state is canceled.
        let finalState = await workflow.state
        XCTAssertEqual(finalState, .canceled, "Workflow should be canceled.")

        // Assert that the continuous trigger did not reach the full threshold.
        XCTAssertLessThan(continuousTrigger.firedCount, threshold, "Continuous trigger should not have fired the full threshold if cancelled early.")
    }
}

public class ContinuousTrigger: WorkflowComponent, TriggerComponent {
    /// The maximum number of times the trigger should fire.
    private let count: Int
    /// The delay between trigger firings.
    private let delay: TimeInterval
    /// A mutable counter to track how many times the trigger has fired.
    public var firedCount: Int = 0

    /// A lazy property that creates a Workflow.Trigger using self.
    public lazy var trigger: Workflow.Trigger = {
        return Workflow.Trigger(
            name: "Continuous Trigger \(self.count)",
            description: "A trigger that fires repeatedly, up to \(self.count) times."
        ) {
            // Simulate waiting for a condition.
            try await Task.sleep(nanoseconds: UInt64(self.delay * 1_000_000_000))
            if self.firedCount < self.count {
                self.firedCount += 1

                // Create a generic Workflow.Task that outputs the counter completion.
                let counter = self.firedCount
                let outputTask = Workflow.Task(
                    name: "Counter",
                    description: "Reports that counter \(counter) is complete"
                ) { _ in
                    return ["\(counter)": "complete"]
                }

                // Return self wrapped as a trigger so it can fire again.
                return [
                    .task(outputTask),
                    .trigger(self.trigger)
                ]
            } else {
                // Once the threshold is reached, return an empty array.
                return []
            }
        }
    }()

    public init(count: Int, delay: TimeInterval = 0.1) {
        self.count = count
        self.delay = delay
    }

    /// Conforms to WorkflowComponent.
    public func toComponent() -> Workflow.Component {
        return .trigger(trigger)
    }

    /// Conforms to TriggerComponent.
    public func waitForTrigger() async throws -> [Workflow.Component] {
        return try await trigger.waitForTrigger()
    }
}
