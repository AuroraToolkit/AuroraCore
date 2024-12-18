//
//  WorkflowManager.swift
//
//
//  Created by Dan Murrell Jr on 8/29/24.
//

import Foundation
import os.log

/// A typealias for a dictionary mapping task names to their corresponding input mappings.
public typealias WorkflowMappings = [String: [String: String]]

/**
 A protocol defining the essential properties and behaviors of a workflow manager, responsible for executing and managing workflows.
 */
public protocol WorkflowManagerProtocol {
    /// The workflow that the manager will execute.
    var workflow: WorkflowProtocol { get set }

    /// Logger instance for logging workflow events.
    var logger: CustomLogger { get }

    /// A dictionary of the final outputs of the workflow.
    var finalOutputs: [String: Any] { get }

    // Workflow-related functions

    /// Starts the workflow execution by triggering the first or current task and proceeds sequentially.
    func start() async

    /// Retrieves the current workflow object.
    func getWorkflow() -> WorkflowProtocol

    /// Retrieves the current workflow state.
    func getWorkflowState() -> WorkflowState

    /// Evaluates and updates the current state of the workflow based on the status of its tasks.
    func evaluateState()

    /// Stops the workflow by marking it as stopped.
    func stopWorkflow()

    /// Retrieves the current task index in the workflow.
    func getCurrentTaskIndex() -> Int

    // Task-related functions

    /// Executes the current task in the workflow, checks required inputs, and updates the task state.
    func executeCurrentTask() async

    /// Completes the current task and progresses to the next task if available.
    func completeTask(_ task: WorkflowTaskProtocol, outputs: [String: Any]) async

    /// Handles a task failure and determines whether to retry the task or stop the workflow.
    func handleTaskFailure(for task: WorkflowTaskProtocol) async
}

/**
 A concrete implementation of the `WorkflowManager` protocol, responsible for managing and executing a workflow.
 */
public class WorkflowManager: WorkflowManagerProtocol {
    public var workflow: WorkflowProtocol
    public let logger = CustomLogger.shared

    // Static mapping of task names to their corresponding input mappings
    public let mappings: [String: [String: String]]

    // Final outputs of the workflow
    public var finalOutputs: [String: Any] = [:]

    /**
     Initializes the workflow manager with a specific workflow.

     - Parameters:
        - workflow: The workflow that the manager will execute.
        - mappings: A dictionary mapping task names to their corresponding input mappings.
     */
    public init(workflow: WorkflowProtocol, mappings: WorkflowMappings = [:]) {
        self.workflow = workflow
        self.mappings = mappings
    }

    // Workflow-related functions
    public func start() async {
        guard workflow.state.isNotStarted || workflow.state.isInProgress else {
            logger.debug("Cannot start workflow. Current state: \(self.workflow.state)", category: "WorkflowManager")
            return
        }

        workflow.markInProgress()
        await executeCurrentTask()
    }

    public func getWorkflow() -> WorkflowProtocol {
        return workflow
    }

    public func getWorkflowState() -> WorkflowState {
        return workflow.state
    }

    public func evaluateState() {
        workflow.evaluateState()
    }

    public func stopWorkflow() {
        guard workflow.state.isNotStarted || workflow.state.isInProgress else {
            logger.debug("Workflow already stopped or completed. Current state: \(self.workflow.state)")
            return
        }

        workflow.markStopped()
    }

    public func getCurrentTaskIndex() -> Int {
        return workflow.currentTaskIndex
    }

    // Task-related functions
    public func executeCurrentTask() async {
        guard workflow.state.isNotStarted || workflow.state.isInProgress else {
            logger.debug("Workflow is unable to continue. Current state is \(self.workflow.state)", category: "WorkflowManager")
            return
        }

        // Ensure there are tasks to execute
        guard workflow.currentTaskIndex < workflow.tasks.count else {
            logger.debug("No tasks to execute in the workflow.", category: "WorkflowManager")
            workflow.tryMarkCompleted() // Mark the workflow as completed if no tasks
            return
        }

        var task = workflow.tasks[workflow.currentTaskIndex]
        populateInputs(for: &task)

        if task.hasRequiredInputs() {
            do {
                task.markInProgress()
                let outputs = try await task.execute()
                await completeTask(task, outputs: outputs)
            } catch {
                logger.error("Task \(task.name) failed with error: \(error.localizedDescription)", category: "WorkflowManager")
                await handleTaskFailure(for: task)
            }
        } else {
            logger.debug("Required inputs not present for task: \(task.name)", category: "WorkflowManager")
            await handleTaskFailure(for: task)
        }
    }

    public func completeTask(_ task: WorkflowTaskProtocol, outputs: [String: Any]) async {
        var updatedTask = task
        updatedTask.markCompleted()
        updatedTask.updateOutputs(with: outputs)
        workflow.updateTask(updatedTask, at: workflow.currentTaskIndex)

        logger.debug("Task \(task.name) completed with outputs: \(outputs)", category: "WorkflowManager")

        if workflow.currentTaskIndex + 1 < workflow.tasks.count {
            workflow.currentTaskIndex += 1
            await executeCurrentTask()
        } else {
            workflow.tryMarkCompleted()
            finalOutputs = outputs
            logger.debug("Final outputs: \(outputs)", category: "WorkflowManager")
        }
    }

    public func handleTaskFailure(for task: WorkflowTaskProtocol) async {
        if task.retryCount < task.maxRetries {
            var updatedTask = task
            updatedTask.incrementRetryCount()
            workflow.updateTask(updatedTask, at: workflow.currentTaskIndex)
            logger.debug("Retrying task \(updatedTask.name). Retry \(updatedTask.retryCount) of \(updatedTask.maxRetries).", category: "WorkflowManager")
            await executeCurrentTask()
        } else {
            var failedTask = task
            failedTask.markFailed()
            workflow.updateTask(failedTask, at: workflow.currentTaskIndex)
            workflow.markFailed(retryCount: failedTask.retryCount)
            logger.debug("Task \(failedTask.name) failed after \(failedTask.maxRetries) retries. Stopping workflow.", category: "WorkflowManager")
        }
    }

    private func populateInputs(for task: inout WorkflowTaskProtocol) {
        let taskName = task.name
        logger.debug("Populating inputs for task: \(taskName)", category: "WorkflowManager")
        guard let taskMappings = mappings[task.name] else { return }
        for (inputKey, sourceMapping) in taskMappings {
            let parts = sourceMapping.split(separator: ".")
            guard parts.count == 2 else { continue }

            let sourceTaskName = String(parts[0])
            let sourceOutputKey = String(parts[1])

            let sourceTask = workflow.tasks.first(where: { $0.name == sourceTaskName })
            if let value = sourceTask?.outputs[sourceOutputKey] {
                logger.debug("Populating input '\(inputKey)' for task '\(taskName)' with value from '\(sourceTaskName).\(sourceOutputKey)'", category: "WorkflowManager")
                task.inputs[inputKey] = value
            } else {
                logger.debug("Failed to populate input '\(inputKey)' for task '\(taskName)'. Source '\(sourceTaskName).\(sourceOutputKey)' not found or empty.", category: "WorkflowManager")
            }
        }
    }
}
