//
//  AgentTriggerTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 4/9/25.
//


import XCTest
@testable import AuroraAgent

final class AgentTriggerTests: XCTestCase {
    
    /// Tests that the trigger fires when the condition is met.
    func testTriggerFiresWhenConditionIsMet() {
        // Flag to track if the trigger fired.
        var didFire = false
        // Variable to capture the emitted event.
        var capturedEvent: TriggerEvent? = nil
        
        // Define a condition that will be met when the query contains "test".
        let condition = QueryContainsCondition(substring: "test")
        
        // Create the trigger with the condition; its action updates the flag and captures the event.
        let trigger = AgentTrigger(conditions: [condition]) { event in
            didFire = true
            capturedEvent = event
        }
        
        // Create a context that satisfies the condition.
        let context: [String: Any] = ["query": "this is a test query"]
        
        // Evaluate the trigger with the provided context.
        trigger.evaluate(context: context)
        
        // Assert that the trigger fired.
        XCTAssertTrue(didFire, "Trigger should fire when condition is met.")
        // Assert that an event was captured.
        XCTAssertNotNil(capturedEvent, "An event should have been captured when the trigger fired.")
        
        // Verify the event's type and parameters.
        if let event = capturedEvent {
            switch event.eventType {
            case .custom(let identifier, let params):
                XCTAssertEqual(identifier, "triggerFired", "Expected the custom event identifier to be 'triggerFired'.")
                // Check that the parameters include the query.
                XCTAssertEqual(params["query"] as? String, context["query"] as? String, "The event parameters should include the correct query.")
            default:
                XCTFail("Expected a custom event type for the trigger.")
            }
        }
    }
    
    /// Tests that the trigger does not fire when the condition is not met.
    func testTriggerDoesNotFireWhenConditionIsNotMet() {
        var didFire = false
        // Define a condition that looks for a substring that is not in the context.
        let condition = QueryContainsCondition(substring: "absent")
        let trigger = AgentTrigger(conditions: [condition]) { event in
            didFire = true
        }
        
        let context: [String: Any] = ["query": "this is a test query"]
        
        // Evaluate the trigger with context that does not meet the condition.
        trigger.evaluate(context: context)
        
        // Assert that the trigger did not fire.
        XCTAssertFalse(didFire, "Trigger should not fire if the condition is not met.")
    }
    
    /// Tests that a trigger with multiple conditions only fires if all conditions are met.
    func testTriggerWithMultipleConditions() {
        var didFire = false
        // First condition is satisfied.
        let condition1 = QueryContainsCondition(substring: "test")
        // Second condition is not satisfied.
        let condition2 = QueryContainsCondition(substring: "nonexistent")
        let trigger = AgentTrigger(conditions: [condition1, condition2]) { event in
            didFire = true
        }
        
        let context: [String: Any] = ["query": "this is a test query"]
        
        // Evaluate the trigger. Since not all conditions are met, the action should not execute.
        trigger.evaluate(context: context)
        
        XCTAssertFalse(didFire, "Trigger should not fire when not all conditions are met.")
    }
}
