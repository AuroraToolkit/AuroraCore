//
//  WorkflowDynamics.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 2/14/25.
//

/**
 A protocol defining a logic-based component in a workflow.

 Components conforming to `LogicComponent` are evaluated to determine if additional components should be executed.
 */
public protocol LogicComponent {
    /// Evaluates conditions and returns an array of additional components to execute.
    func evaluate() async throws -> [Workflow.Component]
}

/**
    A protocol defining a trigger-based component in a workflow.

    Components conforming to `TriggerComponent` wait for a trigger (time-based, event-based, etc.) and return new components when the condition is met.
 */
public protocol TriggerComponent {
    /// Waits for a trigger (time-based, event-based, etc.) and returns new components when the condition is met.
    func waitForTrigger() async throws -> [Workflow.Component]
}
