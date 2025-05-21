//
//  WorkflowComponent.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/14/24.
//

import Foundation

/**
 A protocol representing any component of a workflow.

 Components conforming to `WorkflowComponent` can be tasks, task groups, or any other custom workflow elements.
 This protocol provides a unified interface to convert components into the `Workflow.Component` enum.
 */
public protocol WorkflowComponent {
    /// Converts the component to a `Workflow.Component` type.
    func toComponent() -> Workflow.Component
}

/**
    Allow `Workflow.Component` to conform to `WorkflowComponent` to simplify the conversion process.
    This allows components to be defined outside of `Workflow` and `Workflow.TaskGroup` and still be used in workflows.
 */
extension Workflow.Component: WorkflowComponent {
    public func toComponent() -> Workflow.Component {
        return self
    }
}

/**
 A type-erased wrapper for any `WorkflowComponent`.

 `AnyWorkflowComponent` allows developers to include heterogeneous workflow components in a unified structure.
 It abstracts the underlying type of the component while still conforming to `WorkflowComponent`.
 */
public struct AnyWorkflowComponent: WorkflowComponent {
    /// A closure that returns the corresponding `Workflow.Component`.
    private let _toComponent: () -> Workflow.Component

    /**
     Initializes the type-erased wrapper with a concrete `WorkflowComponent`.

     - Parameter component: A component conforming to `WorkflowComponent`.
     */
    public init<C: WorkflowComponent>(_ component: C) {
        _toComponent = component.toComponent
    }

    /**
     Converts the type-erased component into a `Workflow.Component`.

     - Returns: The `Workflow.Component` representation of the wrapped component.
     */
    public func toComponent() -> Workflow.Component {
        _toComponent()
    }
}

/**
    Extensions to simplify the retrieval of execution details from a `Workflow.Component`.
 */
extension Workflow.Component {
    /// Returns the total execution time of the component.
    var executionTime: TimeInterval {
        switch self {
        case let .task(task):
            return task.detailsHolder.details?.executionTime ?? 0
        case let .taskGroup(group):
            return group.detailsHolder.details?.executionTime ?? 0
        case let .subflow(subflow):
            return subflow.detailsHolder.details?.executionTime ?? 0
        case let .logic(logic):
            return logic.detailsHolder.details?.executionTime ?? 0
        case let .trigger(trigger):
            return trigger.detailsHolder.details?.executionTime ?? 0
        }
    }

    /// Returns the current or final state of the component.
    var state: Workflow.State {
        switch self {
        case let .task(task):
            return task.detailsHolder.details?.state ?? .notStarted
        case let .taskGroup(group):
            return group.detailsHolder.details?.state ?? .notStarted
        case let .subflow(subflow):
            // If subflow outputs are non-empty, assume it completed.
            return subflow.workflow.detailsHolder.details?.state ?? .notStarted
        case let .logic(logic):
            return logic.detailsHolder.details?.state ?? .notStarted
        case let .trigger(trigger):
            return trigger.detailsHolder.details?.state ?? .notStarted
        }
    }

    /// Returns the outputs of the component.
    var outputs: [String: Any] {
        switch self {
        case let .task(task):
            return task.detailsHolder.details?.outputs ?? [:]
        case let .taskGroup(group):
            return group.detailsHolder.details?.outputs ?? [:]
        case let .subflow(subflow):
            return subflow.workflow.outputs
        case let .logic(logic):
            return logic.detailsHolder.details?.outputs ?? [:]
        case let .trigger(trigger):
            return trigger.detailsHolder.details?.outputs ?? [:]
        }
    }

    /// Returns the error that occurred during execution, if any.
    var error: Error? {
        switch self {
        case let .task(task):
            return task.detailsHolder.details?.error
        case let .taskGroup(group):
            return group.detailsHolder.details?.error
        case .subflow:
            return nil
        case let .logic(logic):
            return logic.detailsHolder.details?.error
        case let .trigger(trigger):
            return trigger.detailsHolder.details?.error
        }
    }
}
