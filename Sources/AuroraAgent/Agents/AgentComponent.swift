//
//  AgentComponent.swift
//  AuroraAgent
//
//  Created by Dan Murrell Jr on 4/5/25.
//

import Foundation

/**
 A protocol that represents a component of an agent.

 Components conforming to `AgentComponent` can be descriptions, instructions, skills, skill groups, etc.
 This protocol provides a unified interface to convert components into the `Agent.Component` enum.
 */
public protocol AgentComponent {
    /// Converts the component to an `Agent.Component`.
    func toComponent() -> Agent.Component
}

/**
    Allow `Agent.Component` to conform to `AgentComponent` to simplify the conversion process.
    This allows components to be defined outside of `Agent` and `Agent.SkillGroup` and still be used in agents.
 */
extension Agent.Component: AgentComponent {
    public func toComponent() -> Agent.Component {
        return self
    }
}

/**
 A type-erased wrapper for any `AgentComponent`.

 `AnyAgentComponent` allows developers to include heterogeneous agent components in a unified structure.
 It abstracts the underlying type of the component while still conforming to `AgentComponent`.
 */
public struct AnyAgentComponent: AgentComponent {
    /// A closure that returns the corresponding `Agent.Component`.
    private let _toComponent: () -> Agent.Component

    /**
     Initializes the type-erased wrapper with a concrete `AgentComponent`.

     - Parameter component: A component conforming to `AgentComponent`.
     */
    public init<C: AgentComponent>(_ component: C) {
        self._toComponent = component.toComponent
    }

    /**
     Converts the type-erased component into a `Agent.Component`.

     - Returns: The `Agent.Component` representation of the wrapped component.
     */
    public func toComponent() -> Agent.Component {
        _toComponent()
    }
}

