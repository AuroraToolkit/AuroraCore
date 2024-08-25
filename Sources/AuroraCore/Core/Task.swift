//
//  Task.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/24/24.
//

import Foundation

/**
 A representation of a task within a workflow system. Each task has a name, description, inputs, outputs, status, and timestamps for creation and completion.

 Tasks can transition between statuses such as `pending`, `inProgress`, `completed`, and `failed`. Tasks require inputs to proceed and generate outputs that are passed to the next task in the workflow.

 - Important: Inputs are required by default. To denote an input as optional, append a `?` suffix to the input key.
 */
public struct Task {
    /// Unique identifier for the task.
    public var id: UUID

    /// Name of the task.
    public var name: String

    /// A detailed description of the task.
    public var description: String

    /// The current status of the task.
    public var status: TaskStatus

    /**
     A dictionary representing the inputs required by the task.

     - Note: Inputs are required by default. To specify an input as optional, append a `?` suffix to the input key (e.g., `"optionalInput?"`).
     */
    public var inputs: [String: Any?]

    /// A dictionary representing the outputs produced by the task.
    public private(set) var outputs: [String: Any] = [:]

    /// The timestamp for when the task was created.
    public var creationDate: Date

    /// The timestamp for when the task was completed, if applicable.
    public var completionDate: Date?

    /**
     Initializes a new task with a specified name, description, and inputs. The task starts in the `pending` status by default.

     - Parameters:
        - name: The name of the task.
        - description: A detailed description of the task.
        - inputs: The required inputs for the task. To mark an input as optional, append a `?` suffix to the input key.
        - status: The initial status of the task (default is `.pending`).
     */
    public init(name: String, description: String, inputs: [String: Any?] = [:], status: TaskStatus = .pending) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.inputs = inputs
        self.status = status
        self.creationDate = Date()
    }

    /**
     Marks the task as completed and sets the completion timestamp to the current time.

     - Parameters:
        - outputs: A dictionary of outputs produced by the task.
     */
    public mutating func markCompleted(withOutputs outputs: [String: Any] = [:]) {
        self.status = .completed
        self.completionDate = Date()
        self.outputs = outputs
    }

    /**
     Marks the task as in progress. The status changes to `inProgress`.
     */
    public mutating func markInProgress() {
        self.status = .inProgress
    }

    /**
     Marks the task as failed. This indicates the task could not be completed successfully.
     */
    public mutating func markFailed() {
        self.status = .failed
    }

    /**
     Resets the task to its initial `pending` state, clearing the completion date and outputs if they were previously set.
     */
    public mutating func resetTask() {
        self.status = .pending
        self.completionDate = nil
        self.outputs = [:]
    }

    /**
     Checks if the task has all required inputs.

     - Returns: `true` if all required inputs are present, `false` otherwise.

     - Note: Inputs are required by default. Inputs marked with a `?` suffix are considered optional.
     */
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
}

/**
 An enumeration representing the various statuses that a task can have within its lifecycle.

 - pending: The task is created but not yet started.
 - inProgress: The task is currently being worked on.
 - completed: The task has been successfully completed.
 - failed: The task was unable to be completed successfully.
 */
public enum TaskStatus: String, Codable {
    case pending
    case inProgress
    case completed
    case failed
}
