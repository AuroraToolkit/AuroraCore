//
//  AgentBuilder.swift
//  AuroraAgent
//
//  Created by Dan Murrell Jr on 4/5/25.
//

import Foundation

/**
 A result builder designed to construct agents using a declarative syntax.

    The `AgentBuilder` enables developers to define agents with a clean and concise structure,

 ## Example

    ```swift
    let agent = Agent(name: "Sample Agent", description: "An example agent") {
    }
    ```

    - Note: The `AgentBuilder` is used to construct agents in a declarative manner. Components in an agent must conform to the
    `AgentComponent` protocol, which provides a unified interface for components like skills and skill groups.
 */
@resultBuilder
public struct AgentBuilder {

    /**
     Builds a block of tasks or task groups into a single array of `Agent.Component` objects.

     - Parameter components: A variadic list of agent components (tasks or task groups).
     - Returns: An array of `Agent.Component` objects representing the agent structure.
     */
    public static func buildBlock(_ components: AgentComponent...) -> [Agent.Component] {
        components.map { $0.toComponent() }
    }

    /**
     Conditionally includes a component in the agent if it is non-nil.

     - Parameter component: An optional `AgentComponent` to include.
     - Returns: An array containing the component if it exists, or an empty array otherwise.
     */
    public static func buildIf(_ component: AgentComponent?) -> [Agent.Component] {
        component.map { [$0.toComponent()] } ?? []
    }

    /**
     Conditionally includes one of two blocks of components based on the result of a condition.

     - Parameter first: The components to include if the condition evaluates to true.
     - Returns: An array of `Agent.Component` objects representing the first block.
     */
    public static func buildEither(first: [AgentComponent]) -> [Agent.Component] {
        first.map { $0.toComponent() }
    }

    /**
     Conditionally includes one of two blocks of components based on the result of a condition.

     - Parameter second: The components to include if the condition evaluates to false.
     - Returns: An array of `Agent.Component` objects representing the second block.
     */
    public static func buildEither(second: [AgentComponent]) -> [Agent.Component] {
        second.map { $0.toComponent() }
    }

    /**
     Flattens a nested array of components into a single array.

     - Parameter components: A nested array of agent components to include.
     - Returns: A flattened array of `Agent.Component` objects.
     */
    public static func buildArray(_ components: [[AgentComponent]]) -> [Agent.Component] {
        components.flatMap { $0.map { $0.toComponent() } }
    }
}
