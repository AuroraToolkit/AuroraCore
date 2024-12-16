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
        self._toComponent = component.toComponent
    }

    /**
     Converts the type-erased component into a `Workflow.Component`.

     - Returns: The `Workflow.Component` representation of the wrapped component.
     */
    public func toComponent() -> Workflow.Component {
        _toComponent()
    }
}
