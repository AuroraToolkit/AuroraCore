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
    /// Use `SwiftTask` as an alias for `_Concurrency.Task` internally
    private typealias SwiftTask = _Concurrency.Task

    /// A unique identifier for the workflow.
    public let id: UUID

    /// The name of the workflow.
    public let name: String

    /// A brief description of the workflow.
    public let description: String

    /// The components manager of the workflow, which manages individual tasks, task groups, logic, and triggers.
    public let componentsManager: ComponentsManager

    /// The current state of the workflow. Note this is an asynchronous property for thread-safety.
    public var state: State {
        get async {
            await stateManager.getState()
        }
    }

    /// Holds the execution details of the workflow.
    public let detailsHolder = ExecutionDetailsHolder()

    /// A timer for tracking the execution time of the workflow.
    public var timer = ExecutionTimer()

    /// A collection of outputs resulting from executing one or more tasks.
    public private(set) var outputs: [String: Any] = [:]

    /// The possible states of a workflow.
    public enum State {
        case notStarted
        case inProgress
        case paused
        case canceled
        case completed
        case failed
    }

    /**
     A state management actor for tracking the workflow state.
     */
    private actor StateManager {
        private(set) var state: State = .notStarted

        func getState() -> State {
            return state
        }

        func updateState(to newState: State) {
            state = newState
        }
    }

    /// A state manager instance for tracking the workflow state.
    private let stateManager = StateManager()

    private let logger = CustomLogger.shared


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
        self.componentsManager = ComponentsManager(initialComponents: content())
    }

    // MARK: - Workflow Lifecycle

    /**
        Starts the workflow asynchronously.

        The method iterates over each component in the workflow and executes it asynchronously.
     */
    public mutating func start() async {
        let currentState = await stateManager.getState()

        guard currentState == .notStarted else {
            logger.debug("Workflow \(name) already started or completed.", category: "Workflow")
            return
        }

        await stateManager.updateState(to: .inProgress)

        /// Start tracking execution time
        timer.start()

        do {
            try await executeComponents()
            timer.stop()
            let currentState = await stateManager.getState()
            // Update the execution details in the shared holder.
            detailsHolder.details = ExecutionDetails(
                state: currentState,
                startedAt: timer.startTime,
                endedAt: timer.endTime,
                executionTime: timer.duration ?? 0,
                outputs: outputs
            )
            logger.debug("Workflow \(name) ended with state \(currentState) in \(String(format: "%.2f", timer.duration ?? 0)) seconds.", category: "Workflow")
        } catch {
            await stateManager.updateState(to: .failed)
            detailsHolder.details = ExecutionDetails(
                state: .failed,
                startedAt: timer.startTime,
                endedAt: timer.endTime,
                executionTime: timer.duration ?? 0,
                outputs: outputs,
                error: error
            )
            logger.error("Workflow \(name) failed: \(error.localizedDescription)", category: "Workflow")
        }
    }

    /**
     Cancels the workflow asynchronously.
     */
    public func cancel() async {
        await stateManager.updateState(to: .canceled)
        detailsHolder.details = ExecutionDetails(
                state: .canceled,
                startedAt: nil,
                endedAt: Date(),
                executionTime: 0,
                outputs: outputs
            )
        logger.debug("Workflow \(name) canceled.", category: "Workflow")
    }

    /**
        Pauses the workflow asynchronously.
     */
    public func pause() async {
        guard await stateManager.getState() == .inProgress else {
            logger.debug("Cannot pause workflow \(name) because it is not in progress.", category: "Workflow")
            return
        }

        await stateManager.updateState(to: .paused)
        logger.debug("Workflow \(name) paused.", category: "Workflow")
    }

    /**
        Resumes the workflow asynchronously.
     */
    public mutating func resume() async {
        guard await stateManager.getState() == .paused else {
            logger.debug("Cannot resume workflow \(name) because it is not paused.", category: "Workflow")
            return
        }

        await stateManager.updateState(to: .inProgress)
        logger.debug("Workflow \(name) resumed.", category: "Workflow")

        /// Continue executing workflow where it left off
        await continueExecution()
    }

    /**
        Continues the workflow execution after resuming from a paused state.
     */
    private mutating func continueExecution() async {
        do {
            // Resume execution of remaining components
            try await executeComponents()
            timer.stop()
            let currentState = await stateManager.getState()
            let details = ExecutionDetails(
                state: currentState,
                startedAt: timer.startTime,
                endedAt: timer.endTime,
                executionTime: timer.duration ?? 0,
                outputs: outputs
            )
            detailsHolder.details = details
            logger.debug("Workflow \(name) ended with state \(currentState) after resuming.", category: "Workflow")
        } catch {
            await stateManager.updateState(to: .failed)
            timer.stop()
            let details = ExecutionDetails(
                state: .failed,
                startedAt: timer.startTime,
                endedAt: timer.endTime,
                executionTime: timer.duration ?? 0,
                outputs: outputs,
                error: error
            )
            detailsHolder.details = details
            logger.error("Workflow \(name) failed after resuming: \(error.localizedDescription)", category: "Workflow")
        }
    }

    /**
        Executes the components of the workflow.

        The method iterates over each component in the workflow and executes it asynchronously.
        Task outputs are collected and stored in the `outputs` dictionary for use in subsequent tasks.
     */
    private mutating func executeComponents() async throws {
        var step: Int = 0

        // Remove the next component until pending components is empty.
        while !componentsManager.isEmpty, let component = componentsManager.removeFirst() {

            step += 1
            logger.debug("\(name) Step \(step)")

            // Check state before executing each component
            let currentState = await stateManager.getState()

            switch currentState {
            case .inProgress:
                break
            case .canceled:
                logger.debug("Workflow \(name) execution canceled.", category: "Workflow")
                return
            case .paused:
                logger.debug("Workflow \(name) execution paused.", category: "Workflow")
                await waitUntilResumed() // Wait until the state changes
            default:
                logger.debug("Workflow \(name) in unexpected state: \(currentState)", category: "Workflow")
                throw NSError(
                    domain: "Workflow",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Workflow in unexpected state: \(currentState)"]
                )
            }

            switch component {
            case .task(let task):
                let taskOutputs = try await executeTask(task, workflowOutputs: outputs)
                self.outputs.merge(taskOutputs.mapKeys { "\(task.name).\($0)" }) { _, new in new }

            case .taskGroup(let group):
                let groupOutputs = try await executeTaskGroup(group, workflowOutputs: outputs)
                self.outputs.merge(groupOutputs.mapKeys { "\(group.name).\($0)" }) { _, new in new }

            case .subflow(var subflow):
                // Execute the subflow.
                await subflow.workflow.start()
                // Merge subflow outputs (optionally, you can namespace these).
                self.outputs.merge(subflow.workflow.outputs) { _, new in new }

            case .logic(let logicComponent):
                // Evaluate the logic component, which returns new components.
                let newComponents = try await logicComponent.evaluate()
                componentsManager.insert(newComponents)

            case .trigger(let triggerComponent):
                do {
                    let newComponents = try await triggerComponent.waitForTrigger()
                    componentsManager.insert(newComponents)
                } catch {
                    logger.error("Trigger \(triggerComponent.name) failed: \(error.localizedDescription)", category: "Workflow")
                }
            }

            componentsManager.complete(component)
        }

        let finalState = await stateManager.getState()
        if finalState == .canceled {
            logger.debug("Workflow \(name) canceled during execution.", category: "Workflow")
        } else {
            // If we finish all components without interruption, mark as completed
            await stateManager.updateState(to: .completed)
            logger.debug("Workflow \(name) completed successfully.", category: "Workflow")
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

        // Check for cancelation before starting the task
        if await stateManager.getState() == .canceled {
            logger.debug("Task \(task.name) canceled before execution.", category: "Workflow")
            throw NSError(domain: "Workflow", code: 3, userInfo: [NSLocalizedDescriptionKey: "Workflow was canceled."])
        }

        // Execute the task with resolved inputs
        let outputs = try await task.execute(inputs: resolvedInputs)

        timer.stop()

        // Update the execution details of the task
        let duration = timer.duration ?? 0
        let executionDetails = ExecutionDetails(
            state: .completed,
            startedAt: timer.startTime,
            endedAt: timer.endTime,
            executionTime: duration,
            outputs: outputs)
        task.updateExecutionDetails(executionDetails)

        logger.debug("Task \(task.name) completed in \(String(format: "%.2f", duration)) seconds.", category: "Workflow")

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

        // Update the execution details of the task
        let duration = timer.duration ?? 0
        let executionDetails = ExecutionDetails(
            state: .completed,
            startedAt: timer.startTime,
            endedAt: timer.endTime,
            executionTime: duration,
            outputs: groupOutputs)
        group.updateExecutionDetails(executionDetails)

        logger.debug("Task group \(group.name) completed in \(String(format: "%.2f", duration)) seconds.", category: "Workflow")

        return groupOutputs
    }

    private func waitUntilResumed() async {
        await withCheckedContinuation { continuation in
            SwiftTask {
                while await stateManager.getState() == .paused {
                    try? await SwiftTask.sleep(nanoseconds: 100_000_000) // Check every 100ms
                }
                continuation.resume()
            }
        }
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

        /// A conditional logic component that can be used to insert dynamic components based on logical conditions.
        case logic(Logic)

        /// A trigger component that can be used to insert dynamic components based on external events (e.g. time).
        case trigger(Trigger)

        /// A subflow component that represents a nested workflow.
        case subflow(Subflow)
    }

    // MARK: - Components Manager

    /**
     A helper that manages initial and completed components of a workflow.

        The manager is responsible for storing the components of a workflow, including tasks, task groups, logic, and triggers. As components are executed, they can be removed from the components list and added to the list of completed components.

     - Note: It is the responsibility of the workflow to move components as needed during execution.
     */
    public final class ComponentsManager {
        /// The components that have not yet been executed.
        public private(set) var components: [Component]
        /// The components that have been completed.
        public private(set) var completedComponents: [Component] = []

        /**
            Initializes a new components manager with an optional list of initial components.

            - Parameter initialComponents: An optional list of initial components.
         */
        public init(initialComponents: [Component] = []) {
            self.components = initialComponents
        }

        /**
            Removes the first component from the list of components.

            - Returns: The first component in the list, or nil if the list is empty
         */
        func removeFirst() -> Workflow.Component? {
            guard !components.isEmpty else { return nil }
            return components.removeFirst()
        }

        /**
            Inserts one or more components at the beginning of the list.

            - Parameter components: The components to insert.
        */
        func insert(_ components: [Workflow.Component]) {
            self.components.insert(contentsOf: components, at: 0)
        }

        /**
            Marks a component as completed and moves it to the list of completed components.

            - Parameter component: The component to mark as completed.
         */
        func complete(_ component: Component) {
            completedComponents.append(component)
        }

        /**
            Checks if the components list is empty.

            - Returns: `true` if the components list is empty, otherwise `false`.
         */
        var isEmpty: Bool {
            components.isEmpty
        }
    }


    // MARK: - Execution Details

    /**
        Represents the details of a workflow or task execution, used for logging and reporting.
     */
    public struct ExecutionDetails {
        /// The state of the workflow or task after execution.
        public let state: Workflow.State

        /// The time when the workflow or task started execution.
        public let startedAt: Date?

        /// The time when the workflow or task ended execution.
        public let endedAt: Date?

        /// The time taken to execute the workflow or task in seconds.
        public let executionTime: TimeInterval

        /// The outputs produced by the workflow or task.
        public let outputs: [String: Any]

        /// An error that occurred during execution, if any.
        public let error: Error?

        public init(state: Workflow.State, startedAt: Date?, endedAt: Date?, executionTime: TimeInterval, outputs: [String: Any], error: Error? = nil) {
            self.state = state
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.executionTime = executionTime
            self.outputs = outputs
            self.error = error
        }
    }

    /**
        A holder for the execution details of a workflow, task, or task group, used to mutate details after execution.
     */
    public final class ExecutionDetailsHolder {
        public var details: ExecutionDetails?

        public init(details: ExecutionDetails? = nil) {
            self.details = details
        }
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

        /// Holds the execution details of the task.
        public let detailsHolder = ExecutionDetailsHolder()

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

        /**
            Updates the execution details of the task.

            - Parameter details: The updated execution details.

            This method allows the workflow to update the task details after execution.
         */
        public func updateExecutionDetails(_ details: ExecutionDetails) {
            detailsHolder.details = details
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

        /// Holds the execution details of the task group.
        public let detailsHolder = ExecutionDetailsHolder()


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

        /**
            Updates the execution details of the task group.

            - Parameter details: The updated execution details.

            This method allows the workflow to update the task group details after execution.
         */
        public func updateExecutionDetails(_ details: ExecutionDetails) {
            detailsHolder.details = details
        }

        /// Converts this task group into a `Workflow.Component`.
        public func toComponent() -> Workflow.Component {
            .taskGroup(self)
        }
    }

    // MARK: - Subflow

    /**
        Represents a nested workflow within the main workflow.

        Subflows allow workflows to be composed of other workflows, enabling modular design and reusability.
     */
    public struct Subflow: WorkflowComponent {
        /// A wrapped workflow.
        internal var workflow: Workflow

        /// Reference the execution details of the wrapped workflow.
        public var detailsHolder: ExecutionDetailsHolder {
            return workflow.detailsHolder
        }

        public init(name: String, description: String, @WorkflowBuilder _ content: () -> [Workflow.Component]) {
            self.workflow = Workflow(name: name, description: description, content)
        }

        /// Converts this subflow into a `Workflow.Component`.
        public func toComponent() -> Workflow.Component {
            return .subflow(self)
        }
    }

    // MARK: - Logic

    /**
        Represents a conditional logic component that can evaluate conditions and produce new components.

        Logic components allow workflows to make decisions based on dynamic conditions and insert new components as needed.
     */
    public struct Logic: WorkflowComponent, LogicComponent {
        /// A unique identifier for the logic component.
        public let id: UUID

        /// The name of the logic component.
        public let name: String

        /// A brief description of the logic component.
        public let description: String

        /// A closure that encapsulates the logic to evaluate conditions and produce new components.
        public let evaluateBlock: () async throws -> [Workflow.Component]

        /// Holds the execution details of the logic component.
        public let detailsHolder = ExecutionDetailsHolder()

        /**
         Initializes a new Logic component.

         - Parameters:
            - name: The name of the component.
            - description: A brief description of the component.
            - evaluateBlock: A closure that returns new components when evaluated.
         */
        public init(
            name: String?,
            description: String = "",
            evaluateBlock: @escaping () async throws -> [Workflow.Component]
        ) {
            self.id = UUID()
            self.name = name ?? String(describing: Self.self)
            self.description = description
            self.evaluateBlock = evaluateBlock
        }

        /**
         Evaluates the logic component and returns new components.
         */
        public func evaluate() async throws -> [Workflow.Component] {
            let timer = ExecutionTimer().start()
            let newComponents = try await evaluateBlock()
            timer.stop()
            let duration = timer.duration ?? 0
            let details = ExecutionDetails(
                state: .completed,
                startedAt: timer.startTime,
                endedAt: timer.endTime,
                executionTime: duration,
                outputs: [:]
            )
            updateExecutionDetails(details)
            return newComponents
        }

        /**
         Updates the execution details of the logic component.
         */
        public func updateExecutionDetails(_ details: ExecutionDetails) {
            detailsHolder.details = details
        }

        /// Converts this logic component into a `Workflow.Component`.
        public func toComponent() -> Workflow.Component {
            .logic(self)
        }
    }

    // MARK: - Trigger

    /**
        Represents a trigger component that can wait for a condition and produce new components.

        Trigger components allow workflows to wait for specific conditions (e.g., time-based or event-based) and insert new components as needed.
     */
    public struct Trigger: WorkflowComponent, TriggerComponent {
        /// A unique identifier for the trigger component.
        public let id: UUID

        /// The name of the trigger component.
        public let name: String

        /// A brief description of the trigger component.
        public let description: String

        /// A closure that waits for a condition (e.g., time-based or event-based) and returns new components.
        public let triggerBlock: () async throws -> [Workflow.Component]

        /// Holds the execution details of the trigger component.
        public let detailsHolder = ExecutionDetailsHolder()

        /**
         Initializes a new Trigger component.

         - Parameters:
            - name: The name of the component.
            - description: A brief description of the component.
            - triggerBlock: A closure that waits for a condition and returns new components.
         */
        public init(
            name: String?,
            description: String = "",
            triggerBlock: @escaping () async throws -> [Workflow.Component]
        ) {
            self.id = UUID()
            self.name = name ?? String(describing: Self.self)
            self.description = description
            self.triggerBlock = triggerBlock
        }

        /**
         Waits for the trigger condition and returns new components.
         */
        public func waitForTrigger() async throws -> [Workflow.Component] {
            let timer = ExecutionTimer().start()
            let newComponents = try await triggerBlock()
            timer.stop()
            let duration = timer.duration ?? 0
            let details = ExecutionDetails(
                state: .completed,
                startedAt: timer.startTime,
                endedAt: timer.endTime,
                executionTime: duration,
                outputs: [:]
            )
            updateExecutionDetails(details)
            return newComponents
        }

        /**
         Updates the execution details of the trigger component.
         */
        public func updateExecutionDetails(_ details: ExecutionDetails) {
            detailsHolder.details = details
        }

        /// Converts this trigger component into a `Workflow.Component`.
        public func toComponent() -> Workflow.Component {
            .trigger(self)
        }
    }
}
