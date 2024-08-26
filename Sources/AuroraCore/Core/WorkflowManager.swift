//
//  WorkflowManager.swift
//
//
//  Created by Dan Murrell Jr on 8/25/24.
//

import Foundation
import os.log

/**
 `WorkflowManager` is responsible for managing the execution of workflows and their tasks in a linear sequence.
 It tracks the state of the workflow, handles task execution, manages inputs and outputs, and gracefully handles errors.
 */
public class WorkflowManager {

    private let logger = Logger(subsystem: "com.mutantsoup.AuroraCore", category: "WorkflowManager")


    /// The workflow that the manager will execute.
    private var workflow: Workflow

    /// The index of the current task being executed.
    private var currentTaskIndex: Int = 0

    /**
     Initializes the workflow manager with a specific workflow.

     - Parameter workflow: The workflow that the manager will execute.
     */
    public init(workflow: Workflow) {
        self.workflow = workflow
    }

    /**
     Checks if the workflow has been completed.

     - Returns: `true` if the workflow has a completion date, indicating it is completed; otherwise, `false`.
     */
    public func isCompleted() -> Bool {
        return workflow.completionDate != nil
    }

    /**
     Starts the workflow execution by triggering the first task and proceeds sequentially.
     */
    public func start() {
        guard !isCompleted() else {
            logger.log("Workflow is already completed.")
            return
        }

        guard !workflow.tasks.isEmpty else {
            logger.log("No tasks available in the workflow.")
            return
        }

        executeCurrentTask()
    }

    /**
     Executes the current task and manages the workflow's state as the task completes or fails.
     */
    internal func executeCurrentTask() {
        guard !isCompleted() else {
            logger.log("Workflow is already completed.")
            return
        }

        var task = workflow.tasks[currentTaskIndex]

        if task.hasRequiredInputs() {
            task.markInProgress()
            workflow.updateTask(task, at: currentTaskIndex)

            // Simulate task execution and complete the task
            completeTask(task)
        } else {
            logger.log("Required inputs not present for task: \(task.name)")
            handleTaskFailure(for: task)
            // Stop the workflow due to missing inputs
            return
        }
    }

    /**
     Completes the current task, records its outputs, and progresses to the next task.

     - Parameter task: The task that has been successfully completed.
     */
    private func completeTask(_ task: Task) {
        var updatedTask = task
        updatedTask.markCompleted()
        workflow.updateTask(updatedTask, at: currentTaskIndex)

        logger.log("Task \(task.name) completed with outputs: \(updatedTask.outputs)")

        // Only increment the index if we are moving to the next task
        if currentTaskIndex + 1 < workflow.tasks.count {
            currentTaskIndex += 1
            executeCurrentTask()
        } else {
            completeWorkflow()
        }
    }

    /**
     Marks the workflow as completed and updates the workflow state.
     */
    private func completeWorkflow() {
        workflow.markCompleted()
        logger.log("Workflow completed.")
    }

    /**
     Handles a task failure and determines whether to retry the task or stop the workflow.

     - Parameter task: The task that failed.
     */
    internal func handleTaskFailure(for task: Task) {
        var failedTask = workflow.tasks[currentTaskIndex] // Get the task from the workflow

        // Check if retries are still available
        if failedTask.retryCount < failedTask.maxRetries {
            failedTask.incrementRetryCount() // Increment the retry count
            workflow.updateTask(failedTask, at: currentTaskIndex) // Update the task in the workflow
            logger.log("Retrying task \(failedTask.name). Retry \(failedTask.retryCount) of \(failedTask.maxRetries).")
            executeCurrentTask() // Retry the task without incrementing the currentTaskIndex
        } else {
            failedTask.markFailed() // Mark as failed after max retries
            workflow.updateTask(failedTask, at: currentTaskIndex) // Update the task in the workflow
            logger.log("Task \(failedTask.name) failed after \(failedTask.maxRetries) retries. Stopping workflow.")
            stopWorkflow() // Stop the workflow after failure
        }
    }

    /**
     Stops the workflow by marking it as completed and logs the action.
     */
    internal func stopWorkflow() {
        if !isCompleted() {
            workflow.markCompleted() // Modify the original workflow directly
            logger.log("Workflow has stopped.")
        } else {
            logger.log("Workflow already completed.")
        }
    }

    /**
     Retrieves the current task index being executed in the workflow.

     - Returns: The index of the current task being executed.
     */
    public func getCurrentTaskIndex() -> Int {
        return currentTaskIndex
    }

    /**
     Returns the current state of the workflow.

     - Returns: A string representation of the workflow's state.
     */
    public func getWorkflowState() -> String {
        return isCompleted() ? "Completed" : "In Progress"
    }

    /**
     Returns the current workflow.

     - Returns: The current `Workflow` object.
     */
    public func getWorkflow() -> Workflow {
        return workflow
    }
}
