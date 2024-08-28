//
//  Workflow.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/24/24.
//

import Foundation
import os.log

/**
 A workflow represents a collection of tasks that are executed in sequence, with tracking of their statuses and timestamps.

 The workflow can be marked as complete once all tasks are either completed or failed.
 */
public struct Workflow {
    /// Unique identifier for the workflow.
    public var id: UUID

    /// Name of the workflow.
    public var name: String

    /// A detailed description of the workflow.
    public var description: String

    /// The collection of tasks within this workflow.
    public private(set) var tasks: [Task]

    /// Index of the currently executing task.
    private var currentTaskIndex: Int = 0

    /// The state of the workflow.
    public internal(set) var state: WorkflowState = .notStarted

    /// Logger instance for logging workflow events.
    private let logger = Logger(subsystem: "com.mutantsoup.AuroraCore", category: "Workflow")

    /**
     Initializes a new workflow with a specified name, description, and tasks.

     - Parameters:
        - name: The name of the workflow.
        - description: A detailed description of the workflow.
        - tasks: An optional array of tasks to be added to the workflow (default is an empty array).
     */
    public init(name: String, description: String, tasks: [Task] = []) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.tasks = tasks
    }

    /**
     Attempts to mark the workflow as completed. This will only succeed if there are no active tasks (i.e., tasks that are either `pending` or `inProgress`).

     If there are active tasks, the workflow will remain in its current state, and no changes will be made to its status.

     - Important: This function does not forcibly complete the workflow if there are active tasks. Use this function when you want to ensure that all tasks are completed before marking the workflow as finished.

     - Returns: `true` if the workflow was successfully marked as completed, `false` if there are still active tasks preventing completion.
     */
    @discardableResult
    public mutating func tryMarkCompleted() -> Bool {
        // Check if there are any active tasks
        let activeTasksExist = tasks.contains { $0.status == .pending || $0.status == .inProgress }

        if !activeTasksExist {
            self.state = .completed(Date())
            return true
        } else {
            // Do not mark the workflow as completed if there are active tasks
            logger.log("Cannot mark workflow as completed. There are still active tasks.")
            return false
        }
    }

    /// Updates the state of the workflow to `stopped`.
    public mutating func markStopped() {
        self.state = .stopped(Date())
    }

    /// Updates the state of the workflow to `failed`.
    public mutating func markFailed(retryCount: Int) {
        self.state = .failed(Date(), retryCount)
    }

    /// Helper method to check if the workflow is completed.
    public func isCompleted() -> Bool {
        if case .completed(_) = state {
            return true
        }
        return false
    }

    /**
     Adds a new task to the workflow.

     - Parameter task: The task to be added to the workflow.
     */
    public mutating func addTask(_ task: Task) {
        tasks.append(task)
    }

    /**
     Resets all tasks in the workflow to the `pending` state, and clears the workflow's completion date.
     */
    public mutating func resetWorkflow() {
        tasks.indices.forEach { tasks[$0].resetTask() }
        self.currentTaskIndex = 0
        self.state = .notStarted
    }

    /**
     Retrieves all tasks that have been completed within the workflow.

     - Returns: An array of tasks that are marked as completed.
     */
    public func completedTasks() -> [Task] {
        return tasks.filter { $0.status == .completed }
    }

    /**
     Retrieves all tasks that are still pending or in progress within the workflow.

     - Returns: An array of tasks that are either pending or in progress.
     */
    public func activeTasks() -> [Task] {
        return tasks.filter { $0.status == .pending || $0.status == .inProgress }
    }

    /**
     Starts the execution of the workflow by triggering the first task.
     */
    public mutating func start() {
        executeNextTask()
    }

    /**
     Executes the next task in the workflow that is in the `pending` state.
     */
    private mutating func executeNextTask() {
        guard currentTaskIndex < tasks.count else {
            tryMarkCompleted()
            return
        }

        var task = tasks[currentTaskIndex]
        task.markInProgress()

        // Here we would typically execute the task's logic (e.g., async call)
        // Simulating task completion
        if task.hasRequiredInputs() {
            completeCurrentTask()
        } else {
            handleTaskFailure()
        }
    }

    /**
     Completes the current task, processes its outputs, and proceeds to the next task.
     */
    private mutating func completeCurrentTask() {
        // Complete the task at the current index using its own outputs
        tasks[currentTaskIndex].markCompleted(withOutputs: tasks[currentTaskIndex].outputs)

        // Check if there are more tasks to execute
        if currentTaskIndex + 1 < tasks.count {
            // Increment the index only when there are more tasks left
            currentTaskIndex += 1
            executeNextTask()
        } else {
            // If no tasks are left, mark the workflow as completed
            tryMarkCompleted()
        }
    }

    /**
     Updates a task at a given index in the workflow.

     - Parameters:
        - task: The updated task to be placed at the given index.
        - index: The index of the task to be updated.
     */
    public mutating func updateTask(_ task: Task, at index: Int) {
        guard index >= 0 && index < tasks.count else { return }
        tasks[index] = task
    }

    /**
     Handles the failure of the current task. The workflow may either stop or attempt to recover based on retry logic.

     If the task has retries left, it will be retried. Otherwise, the workflow will be marked as failed.
     */
    private mutating func handleTaskFailure() {
        var failedTask = tasks[currentTaskIndex]

        // Check if the task can be retried
        if failedTask.canRetry() {
            failedTask.incrementRetryCount()
            logger.log("Retrying task \(failedTask.name). Attempt \(failedTask.retryCount) of \(failedTask.maxRetries).")

            // Retry the task by setting its state to pending and re-executing it
            failedTask.resetTask()
            updateTask(failedTask, at: currentTaskIndex) // Use the updateTask function for consistency
            executeNextTask()
        } else {
            // Mark the task as failed and update the workflow state
            failedTask.markFailed()
            updateTask(failedTask, at: currentTaskIndex) // Use the updateTask function for consistency
            logger.log("Task \(failedTask.name) failed after \(failedTask.retryCount) retries. Stopping workflow.")
            markFailed(retryCount: failedTask.retryCount)
        }
    }
}

/**
 `WorkflowState` represents the various states a workflow can be in during its lifecycle.

 - inProgress: The workflow is currently being executed.
 - stopped: The workflow has been manually stopped.
 - completed: The workflow has successfully completed all tasks.
 - failed: The workflow has failed after exhausting all retries for a task.
 */
public enum WorkflowState: Equatable {
    case notStarted
    case inProgress
    case stopped(Date)
    case completed(Date)
    case failed(Date, Int) // failed date, retry count

    // Computed properties to check state
    public var isNotStarted: Bool {
        if case .notStarted = self { return true }
        return false
    }

    public var isInProgress: Bool {
        if case .inProgress = self { return true }
        return false
    }

    public var isStopped: Bool {
        if case .stopped = self { return true }
        return false
    }

    public var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    public var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
