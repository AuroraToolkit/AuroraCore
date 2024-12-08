//
//  Task.swift
//
//
//  Created by Dan Murrell Jr on 8/29/24.
//

import Foundation

/**
 A protocol defining the essential properties and behaviors of a task within a workflow system.
 */
public protocol WorkflowTaskProtocol {
    /// Unique identifier for the task.
    var id: UUID { get }

    /// Name of the task.
    var name: String { get }

    /// A detailed description of the task.
    var description: String { get }

    /// The current status of the task.
    var status: TaskStatus { get set }

    /// The inputs required by the task.
    var inputs: [String: Any?] { get set }

    /// The outputs produced by the task.
    var outputs: [String: Any] { get set }

    /// The timestamp for when the task was created.
    var creationDate: Date { get }

    /// The timestamp for when the task was completed, if applicable.
    var completionDate: Date? { get set }

    /// The number of times the task has been retried.
    var retryCount: Int { get set }

    /// The maximum number of retries allowed for this task.
    var maxRetries: Int { get }

    /// Executes the task. This method can be either synchronous or asynchronous.
    func execute() async throws -> [String: Any]

    /// Marks the task as completed and sets the completion timestamp to the current time.
    mutating func markCompleted()

    /// Marks the task as in progress.
    mutating func markInProgress()

    /// Marks the task as failed.
    mutating func markFailed()

    /// Resets the task to its initial `pending` state.
    mutating func resetTask()

    /// Increments the retry count for the task.
    mutating func incrementRetryCount()

    /// Checks whether the task can still be retried.
    func canRetry() -> Bool

    /// Checks if the task has all required inputs.
    func hasRequiredInputs() -> Bool

    /// Updates the task outputs with new values.
    func updateOutputs(with newOutputs: [String: Any])
}

/**
 A concrete implementation of the `Task` protocol, representing a task within a workflow system.
 */
public class WorkflowTask: WorkflowTaskProtocol {
    public var id: UUID
    public var name: String
    public var description: String
    public var status: TaskStatus
    public var inputs: [String: Any?]
    public var outputs: [String: Any] = [:]
    public var creationDate: Date
    public var completionDate: Date?
    public var retryCount: Int = 0
    public var maxRetries: Int

    /// An optional inline execution block for the task.
    private var executeBlock: (([String: Any]) async throws -> [String: Any])?

    /**
     Initializes a new `WorkflowTask` with a specified name, description, and inputs.

     - Parameters:
        - name: The name of the task.
        - description: A detailed description of the task.
        - inputs: The required inputs for the task.
        - maxRetries: The maximum number of retries allowed for this task.
        - status: The initial status of the task (default is `.pending`).
     */
    public init(
        name: String? = nil,
        description: String,
        inputs: [String: Any?] = [:],
        maxRetries: Int = 0,
        status: TaskStatus = .pending,
        executeBlock: (([String: Any]) async throws -> [String: Any])? = nil
    ) {
        self.id = UUID()
        self.name = name ?? String(describing: type(of: self)) // Default to the class name
        self.description = description
        self.inputs = inputs
        self.status = status
        self.creationDate = Date()
        self.maxRetries = maxRetries
        self.executeBlock = executeBlock
    }


    public func execute() async throws -> [String: Any] {
        if let executeBlock = executeBlock {
            // Use inline execution block if provided
            return try await executeBlock(inputs.compactMapValues { $0 })
        } else {
            throw NSError(
                domain: "WorkflowTask",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Subclasses must override execute() or provide an executeBlock."]
            )
        }
    }

    /**
     Marks the `LLMTask` as completed.
     */
    public func markCompleted() {
        self.status = .completed
        self.completionDate = Date()
    }

    public func markInProgress() {
        self.status = .inProgress
    }

    public func markFailed() {
        self.status = .failed
    }

    public func resetTask() {
        self.status = .pending
        self.completionDate = nil
        self.outputs = [:]
        self.retryCount = 0
    }

    public func incrementRetryCount() {
        retryCount += 1
    }

    public func canRetry() -> Bool {
        return retryCount < maxRetries
    }

    public func hasRequiredInputs() -> Bool {
        return inputs.allSatisfy { key, value in
            // If the key ends with `?`, treat it as optional and skip the check
            if key.hasSuffix("?") {
                return true
            }
            // Check if the value is nil by casting it to Optional<Any>
            let mirror = Mirror(reflecting: value as Any)
            return mirror.displayStyle != .optional || mirror.children.first != nil
        }
    }

    public func updateOutputs(with newOutputs: [String: Any]) {
        self.outputs.merge(newOutputs, uniquingKeysWith: { $1 })
    }
}

/**
 An enumeration representing the various statuses that a task can have within its lifecycle, each associated with a timestamp.

 - pending: The task is created but not yet started.
 - inProgress: The task is currently being worked on.
 - completed: The task has been successfully completed.
 - failed: The task was unable to be completed successfully.
 */
public enum TaskStatus: Codable, Equatable {
    case pending
    case inProgress
    case completed
    case failed
}
