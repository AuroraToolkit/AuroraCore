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

    /// A collection of outputs resulting from executing one or more tasks.
    public private(set) var outputs: [String: Any] = [:]

    private let logger = CustomLogger.shared


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

    // MARK: - Workflow Lifecycle

    /**
        Starts the workflow asynchronously.

        The method iterates over each component in the workflow and executes it asynchronously.
     */
    public mutating func start() async {
        guard state == .notStarted else {
            logger.debug("Workflow \(name) already started or completed.", category: "Workflow")
            return
        }

        state = .inProgress

        let timer = ExecutionTimer().start()

        do {
            try await executeComponents()
            state = .completed
            timer.stop()
            logger.debug("Workflow \(name) completed successfully in \(String(format: "%.2f", timer.duration ?? 0)) seconds.", category: "Workflow")
        } catch {
            state = .failed
            logger.error("Workflow \(name) failed: \(error.localizedDescription)", category: "Workflow")
        }
    }

    /**
        Executes the components of the workflow.

        The method iterates over each component in the workflow and executes it asynchronously.
        Task outputs are collected and stored in the `outputs` dictionary for use in subsequent tasks.
     */
    private mutating func executeComponents() async throws {
        for component in components {
            switch component {
            case .task(let task):
                let taskOutputs = try await executeTask(task, workflowOutputs: outputs)
                self.outputs.merge(taskOutputs.mapKeys { "\(task.name).\($0)" }) { _, new in new }

            case .taskGroup(let group):
                let taskGroupOutputs = try await executeTaskGroup(group, workflowOutputs: outputs)
                self.outputs.merge(taskGroupOutputs.mapKeys { "\(group.name).\($0)" }) { _, new in new }
            }
        }
    }

    /**
        Resolves the inputs for a task using the outputs of previously executed tasks.

        - Parameters:
            - task: The task for which to resolve inputs.
            - workflowOutputs: A dictionary of outputs from previously executed tasks.
        - Returns: A dictionary of resolved inputs for the task.

        The method resolves dynamic references in the task inputs by looking up the corresponding output keys in the `workflowOutputs` dictionary.
        Dynamic references are denoted with `{` and `}` brackets in the input values. For example, `{TaskName.OutputKey}`.
        Dynamic references are replaced with the actual output values from the workflow. If an output key is not found, the reference is left unresolved.
        If an input key is not a dynamic reference, the value is used as is.
     */
    private func resolveInputs(for task: Task, using workflowOutputs: [String: Any]) -> [String: Any] {
        task.inputs.reduce(into: [String: Any]()) { resolvedInputs, entry in
            let (key, value) = entry
            if let stringValue = value as? String, stringValue.hasPrefix("{") && stringValue.hasSuffix("}") {
                let dynamicKey = String(stringValue.dropFirst().dropLast()) // Extract key from {key}
                resolvedInputs[key] = workflowOutputs[dynamicKey]
            } else {
                resolvedInputs[key] = value
            }
        }
    }

    /**
        Executes a task asynchronously and returns the outputs produced by the task.

        - Parameters:
            - task: The task to be executed
            - workflowOutputs: A dictionary of outputs from previously executed tasks.
        - Returns: A dictionary of outputs produced by the task.
     */
    private func executeTask(_ task: Task, workflowOutputs: [String: Any]) async throws -> [String: Any] {
        logger.debug("Executing task: \(task.name)", category: "Workflow")

        let timer = ExecutionTimer().start()

        // Resolve inputs dynamically
        let resolvedInputs = resolveInputs(for: task, using: workflowOutputs)

        // Execute the task with resolved inputs
        let outputs = try await task.execute(inputs: resolvedInputs)

        timer.stop()

        logger.debug("Task \(task.name) completed in \(String(format: "%.2f", timer.duration ?? 0)) seconds.", category: "Workflow")

        return outputs
    }

    /**
        Executes a task group asynchronously and returns the outputs produced by the group.

        - Parameters:
            - group: The task group to be executed.
            - workflowOutputs: A dictionary of outputs from previously executed tasks.
        - Returns: A dictionary of outputs produced by the task group.

        Task groups can execute tasks sequentially or in parallel based on the `mode` property.
     */
    private func executeTaskGroup(_ group: TaskGroup, workflowOutputs: [String: Any]) async throws -> [String: Any]  {
        logger.debug("Executing task group: \(group.name)", category: "Workflow")

        let timer = ExecutionTimer().start()

        let queue = DispatchQueue(label: "com.workflow.groupOutputs")
        var groupOutputs: [String: Any] = [:]

        switch group.mode {
        case .sequential:
            for task in group.tasks {
                let taskOutputs = try await executeTask(task, workflowOutputs: workflowOutputs)
                groupOutputs.merge(taskOutputs.mapKeys { "\(task.name).\($0)" }) { _, new in new }
            }
        case .parallel:
            try await withThrowingTaskGroup(of: Void.self) { taskGroup in
                for task in group.tasks {
                    taskGroup.addTask {
                        let taskOutputs = try await self.executeTask(task, workflowOutputs: workflowOutputs)
                        queue.sync {    // Ensure thread safety when updating groupOutputs
                            groupOutputs.merge(taskOutputs.mapKeys { "\(task.name).\($0)" }) { _, new in new }
                        }
                    }
                }

                // Cancel all remaining tasks if one throws an error
                do {
                    while try await taskGroup.next() != nil {}
                } catch {
                    taskGroup.cancelAll()
                    throw error
                }
            }
        }

        timer.stop()

        logger.debug("Task group \(group.name) completed in \(String(format: "%.2f", timer.duration ?? 0)) seconds.", category: "Workflow")

        return groupOutputs
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
        public let inputs: [String: Any]

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
            name: String?,
            description: String = "",
            inputs: [String: Any?] = [:],
            executeBlock: (([String: Any]) async throws -> [String: Any])? = nil
        ) {
            self.id = UUID()
            self.name = name ?? String(describing: Self.self) // Default to the class name
            self.description = description
            self.inputs = inputs.compactMapValues { $0 }
            self.executeBlock = executeBlock
        }

        /**
         Executes the task using the provided inputs.

         - Parameter inputs: A dictionary of inputs required by the task.
         - Returns: A dictionary of outputs produced by the task.
         - Throws: An error if the task execution logic is not provided or fails during execution.
         */
        public func execute(inputs: [String: Any?] = [:]) async throws -> [String: Any] {
            let mergedInputs = self.inputs
                .merging(inputs as [String : Any]) { (_, new) in new } // Runtime inputs take precedence
                .compactMapValues { $0 }
            if let executeBlock = executeBlock {
                return try await executeBlock(mergedInputs)
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

        ///  How tasks are executed, sequentially, or in parallel
        public let mode: ExecutionMode

        /// Execute tasks sequentially in the order they were added, or simultaneously in parallel.
        public enum ExecutionMode {
            case sequential
            case parallel
        }

        /**
         Initializes a new task group.

         - Parameters:
            - name: The name of the task group.
            - description: A brief description of the task group (default is an empty string).
            - content: A closure that declares the tasks within the group.
         */
        public init(name: String, description: String = "", mode: ExecutionMode = .sequential, @WorkflowBuilder _ content: () -> [Workflow.Component]) {
            self.id = UUID()
            self.name = name
            self.description = description
            self.mode = mode
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
