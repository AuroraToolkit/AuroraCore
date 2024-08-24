//
//  Task.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/24/24.
//

import Foundation

/**
 A representation of a task within a workflow system. Each task has a name, description, status, and timestamps for creation and completion.

 Tasks can transition between statuses such as `pending`, `inProgress`, `completed`, and `failed`.
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

    /// The timestamp for when the task was created.
    public var creationDate: Date

    /// The timestamp for when the task was completed, if applicable.
    public var completionDate: Date?

    /**
     Initializes a new task with a specified name and description. The task starts in the `pending` status by default.

     - Parameters:
        - name: The name of the task.
        - description: A detailed description of the task.
        - status: The initial status of the task (default is `.pending`).
     */
    public init(name: String, description: String, status: TaskStatus = .pending) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.status = status
        self.creationDate = Date()
    }

    /**
     Marks the task as completed and sets the completion timestamp to the current time.
     */
    public mutating func markCompleted() {
        self.status = .completed
        self.completionDate = Date()
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
     Resets the task to its initial `pending` state, clearing the completion date if it was previously set.
     */
    public mutating func resetTask() {
        self.status = .pending
        self.completionDate = nil
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
