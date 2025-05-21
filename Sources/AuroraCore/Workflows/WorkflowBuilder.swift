//
//  WorkflowBuilder.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/14/24.
//

/**
 A result builder designed to construct workflows using a declarative syntax.

 The `WorkflowBuilder` enables developers to define workflows with a clean and concise structure,
 allowing for the creation of `Workflow` objects containing `TaskGroup` and `Task` instances.

 ## Example

 ```swift
 let workflow = Workflow(name: "Sample Workflow", description: "An example workflow") {
     Workflow.TaskGroup(name: "Group 1", description: "First group") {
         Workflow.Task(name: "Task 1", description: "Perform task 1") { _ in
             ["result": "Task 1 complete"]
         }
         Workflow.Task(name: "Task 2", description: "Perform task 2", inputs: ["result": nil]) { inputs in
             guard let result = inputs["result"] as? String else { return [:] }
             return ["output": "\(result), and Task 2 complete"]
         }
     }
     Workflow.Task(name: "Task 3", description: "Independent task") { _ in
         ["final": "Workflow complete"]
     }
 }
 ```
    - Note: The `WorkflowBuilder` is used to construct workflows in a declarative manner. Components in a workflow must conform to the
 `WorkflowComponent` protocol, which provides a unified interface for tasks and task groups.
 */
@resultBuilder
public struct WorkflowBuilder {
    /**
     Builds a block of tasks or task groups into a single array of `Workflow.Component` objects.

     - Parameter components: A variadic list of workflow components (tasks or task groups).
     - Returns: An array of `Workflow.Component` objects representing the workflow structure.
     */
    public static func buildBlock(_ components: WorkflowComponent...) -> [Workflow.Component] {
        components.map { $0.toComponent() }
    }

    /**
     Conditionally includes a component in the workflow if it is non-nil.

     - Parameter component: An optional `WorkflowComponent` to include.
     - Returns: An array containing the component if it exists, or an empty array otherwise.
     */
    public static func buildIf(_ component: WorkflowComponent?) -> [Workflow.Component] {
        component.map { [$0.toComponent()] } ?? []
    }

    /**
     Conditionally includes one of two blocks of components based on the result of a condition.

     - Parameter first: The components to include if the condition evaluates to true.
     - Returns: An array of `Workflow.Component` objects representing the first block.
     */
    public static func buildEither(first: [WorkflowComponent]) -> [Workflow.Component] {
        first.map { $0.toComponent() }
    }

    /**
     Conditionally includes one of two blocks of components based on the result of a condition.

     - Parameter second: The components to include if the condition evaluates to false.
     - Returns: An array of `Workflow.Component` objects representing the second block.
     */
    public static func buildEither(second: [WorkflowComponent]) -> [Workflow.Component] {
        second.map { $0.toComponent() }
    }

    /**
     Flattens a nested array of components into a single array.

     - Parameter components: A nested array of workflow components to include.
     - Returns: A flattened array of `Workflow.Component` objects.
     */
    public static func buildArray(_ components: [[WorkflowComponent]]) -> [Workflow.Component] {
        components.flatMap { $0.map { $0.toComponent() } }
    }
}
