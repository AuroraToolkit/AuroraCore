//
//  WorkflowManager.swift
//
//
//  Created by Dan Murrell Jr on 8/25/24.
//

import Foundation

/**
 `WorkflowManager` is responsible for managing the execution of workflows and their tasks in a linear sequence.
 It tracks the state of the workflow, handles task execution, manages inputs and outputs, and gracefully handles errors.
 */
public class WorkflowManager {

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
            print("Workflow is already completed.")
            return
        }

        guard !workflow.tasks.isEmpty else {
            print("No tasks available in the workflow.")
            return
        }

        executeCurrentTask()
    }

    /**
     Executes the current task and manages the workflow's state as the task completes or fails.
     */
    internal func executeCurrentTask() {
        guard !isCompleted() else {
            print("Workflow is already completed.")
            return
        }

        var task = workflow.tasks[currentTaskIndex]

        if task.hasRequiredInputs() {
            task.markInProgress()
            workflow.updateTask(task, at: currentTaskIndex)

            // Simulate task execution and complete the task
            completeTask(task)
        } else {
            print("Required inputs not present for task: \(task.name)")
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

        print("Task \(task.name) completed with outputs: \(updatedTask.outputs)")
        currentTaskIndex += 1

        if currentTaskIndex < workflow.tasks.count {
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
        print("Workflow completed.")
    }

    /**
     Handles a task failure and stops the workflow.

     - Parameter task: The task that failed.
     */
    private func handleTaskFailure(for task: Task) {
        var failedTask = task
        failedTask.markFailed()
        workflow.updateTask(failedTask, at: currentTaskIndex)

        // Ensure the workflow stops here, don't let it continue
        print("Task \(task.name) failed. Workflow stopping.")
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
