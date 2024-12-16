//
//  Workflow.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/14/24.
//

import Foundation

/**
 A declarative representation of a workflow, consisting of tasks and task groups.

 The `Workflow` struct allows developers to define complex workflows using a clear and concise declarative syntax.
 Workflows are composed of individual tasks and task groups, enabling sequential and parallel execution patterns.

 - Note: Tasks and task groups are represented by the `Workflow.Task` and `Workflow.TaskGroup` types, respectively.
 */
public struct Workflow {
    /// A unique identifier for the workflow.
    public let id: UUID

    /// The name of the workflow.
    public let name: String

    /// A brief description of the workflow.
    public let description: String

    /// The components of the workflow, which can be individual tasks or task groups.
    public let components: [Component]

    /// The current state of the workflow.
    public private(set) var state: State = .notStarted

    public enum State {
        case notStarted
        case inProgress
        case completed
        case failed
    }

    /**
     Initializes a new `Workflow`.

     - Parameters:
        - name: The name of the workflow.
        - description: A brief description of the workflow.
        - content: A closure that declares the tasks and task groups for the workflow.
     */
    public init(name: String, description: String, @WorkflowBuilder _ content: () -> [Component]) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.components = content()
    }

    // MARK: - Nested Types

    /**
     Represents a building block of a workflow, which can be either a task or a task group.
     */
    public enum Component {
        /// A single task within the workflow.
        case task(Task)

        /// A group of tasks that may execute in parallel or sequentially.
        case taskGroup(TaskGroup)
    }

    // MARK: - Task

    /**
     Represents an individual unit of work in the workflow.

     Tasks define specific actions or operations within a workflow. Each task may include inputs
     and provide outputs after execution. Tasks can execute asynchronously using the `execute` method.
     */
    public struct Task: WorkflowComponent {
        /// A unique identifier for the task.
        public let id: UUID

        /// The name of the task.
        public let name: String

        /// A brief description of the task.
        public let description: String

        /// The required inputs for the task.
        public let inputs: [String: Any?]

        /// A closure representing the work to be performed by the task.
        public let executeBlock: (([String: Any]) async throws -> [String: Any])?

        /**
         Initializes a new task.

         - Parameters:
            - name: The name of the task.
            - description: A brief description of the task (default is an empty string).
            - inputs: The required inputs for the task (default is an empty dictionary).
            - executeBlock: An optional closure defining the work to be performed by the task.
         */
        public init(
            name: String,
            description: String = "",
            inputs: [String: Any?] = [:],
            executeBlock: (([String: Any]) async throws -> [String: Any])? = nil
        ) {
            self.id = UUID()
            self.name = name
            self.description = description
            self.inputs = inputs
            self.executeBlock = executeBlock
        }

        /**
         Executes the task using the provided inputs.

         - Parameter inputs: A dictionary of inputs required by the task.
         - Returns: A dictionary of outputs produced by the task.
         - Throws: An error if the task execution logic is not provided or fails during execution.
         */
        public func execute(inputs: [String: Any]) async throws -> [String: Any] {
            if let executeBlock = executeBlock {
                return try await executeBlock(inputs)
            } else {
                throw NSError(
                    domain: "Workflow.Task",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No execution logic provided for task: \(name)"]
                )
            }
        }

        /// Converts this task into a `Workflow.Component`.
        public func toComponent() -> Workflow.Component {
            .task(self)
        }
    }

    // MARK: - TaskGroup

    /**
     Represents a collection of related tasks within the workflow.

     Task groups can specify whether their tasks execute sequentially or in parallel.
     Groups provide logical grouping and execution flexibility for tasks within a workflow.
     */
    public struct TaskGroup: WorkflowComponent {
        /// A unique identifier for the task group.
        public let id: UUID

        /// The name of the task group.
        public let name: String

        /// A brief description of the task group.
        public let description: String

        /// The tasks contained within the group.
        public let tasks: [Task]

        /**
         Initializes a new task group.

         - Parameters:
            - name: The name of the task group.
            - description: A brief description of the task group (default is an empty string).
            - content: A closure that declares the tasks within the group.
         */
        public init(name: String, description: String = "", @WorkflowBuilder _ content: () -> [Workflow.Component]) {
            self.id = UUID()
            self.name = name
            self.description = description
            self.tasks = content().compactMap {
                if case let .task(task) = $0 {
                    return task
                }
                return nil
            }
        }

        /// Converts this task group into a `Workflow.Component`.
        public func toComponent() -> Workflow.Component {
            .taskGroup(self)
        }
    }
}
