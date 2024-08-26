//
//  Workflow.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/24/24.
//

import Foundation

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

    /// The timestamp for when the workflow was created.
    public var creationDate: Date

    /// The timestamp for when the workflow was completed, if applicable.
    public var completionDate: Date?

    /// Index of the currently executing task.
    private var currentTaskIndex: Int = 0

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
        self.creationDate = Date()
    }

    /**
     Marks the workflow as completed. This only happens if all tasks within the workflow have been marked as either `completed` or `failed`.
     */
    public mutating func markCompleted() {
        guard tasks.allSatisfy({ $0.status == .completed || $0.status == .failed }) else { return }
        self.completionDate = Date()
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
        self.completionDate = nil
        self.currentTaskIndex = 0
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
            markCompleted()
            return
        }

        var task = tasks[currentTaskIndex]
        task.markInProgress()

        // Here we would typically execute the task's logic (e.g., async call)
        // Simulating task completion
        if task.hasRequiredInputs() {
            markTaskCompleted(task)
        } else {
            handleTaskFailure(task)
        }
    }

    /**
     Marks a task as completed, processes its outputs, and proceeds to the next task.

     - Parameters:
        - task: The completed task.
     */
    private mutating func markTaskCompleted(_ task: Task) {
        // Process outputs and pass to the next task if necessary
        tasks[currentTaskIndex].markCompleted(withOutputs: task.outputs)
        currentTaskIndex += 1
        executeNextTask()
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
     Handles the failure of a task. The workflow may either stop or attempt to recover.

     - Parameters:
        - task: The failed task.
     */
    private mutating func handleTaskFailure(_ task: Task) {
        tasks[currentTaskIndex].markFailed()
        // We could add retry logic or recovery mechanisms here
        // For now, we will stop the workflow upon failure
    }
}
