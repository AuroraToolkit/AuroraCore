//
//  WorkflowReporting.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 2/1/25.
//

import Foundation

// MARK: - Workflow Component Report

/**
    A report for an individual workflow component (either a task or a task group).

    This report includes information such as the component's ID, name, description, state, execution time, outputs, and any error messages.
 */
public struct WorkflowComponentReport {
    public let id: UUID
    public let name: String
    public let description: String
    public let state: Workflow.State
    public let executionTime: TimeInterval? // in seconds
    public let outputs: [String: Any]?
    public let childReports: [WorkflowComponentReport]?
    public let error: String?

    public init(
        id: UUID,
        name: String,
        description: String,
        state: Workflow.State,
        executionTime: TimeInterval? = nil,
        outputs: [String: Any]? = nil,
        childReports: [WorkflowComponentReport]? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.state = state
        self.executionTime = executionTime
        self.outputs = outputs
        self.childReports = childReports
        self.error = error
    }
}

// MARK: - Reporting Protocol

/// A protocol that defines the ability to generate a report for a workflow component.
public protocol WorkflowReportable {
    func generateReport() -> WorkflowComponentReport
}

// MARK: - Extensions for Workflow Components

extension Workflow.Task: WorkflowReportable {
    public func generateReport() -> WorkflowComponentReport {
        // Note: Replace placeholder values with actual recorded metrics as needed.
        return WorkflowComponentReport(
            id: self.id,
            name: self.name,
            description: self.description,
            state: .notStarted, // placeholder; update this as execution progresses
            executionTime: nil,
            outputs: nil,
            error: nil
        )
    }
}

extension Workflow.TaskGroup: WorkflowReportable {
    public func generateReport() -> WorkflowComponentReport {
        let childReports = self.tasks.map { $0.generateReport() }
        return WorkflowComponentReport(
            id: self.id,
            name: self.name,
            description: self.description,
            state: .notStarted, // placeholder; update this as execution progresses
            executionTime: nil,
            outputs: nil,
            childReports: childReports,
            error: nil
        )
    }
}

extension Workflow.Component {
    /// Returns the report for this workflow component.
    public var report: WorkflowComponentReport {
        switch self {
        case .task(let task):
            return task.generateReport()
        case .taskGroup(let group):
            return group.generateReport()
        }
    }
}

// MARK: - Overall Workflow Report

/**
    A report that summarizes the overall workflow execution.

    This report includes information such as the workflow's ID, name, description, state, execution time, outputs, component reports, and any error messages.
 */
public struct WorkflowReport {
    public let id: UUID
    public let name: String
    public let description: String
    public let state: Workflow.State
    public let executionTime: TimeInterval? // in seconds
    public let outputs: [String: Any]?
    public let componentReports: [WorkflowComponentReport]
    public let error: String?
    
    public init(
        id: UUID,
        name: String,
        description: String,
        state: Workflow.State,
        executionTime: TimeInterval? = nil,
        outputs: [String: Any]? = nil,
        componentReports: [WorkflowComponentReport] = [],
        error: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.state = state
        self.executionTime = executionTime
        self.outputs = outputs
        self.componentReports = componentReports
        self.error = error
    }
}

// MARK: - Workflow Report Generation

extension Workflow {
    /// Generates an overall report for the workflow.
    public func generateReport() async -> WorkflowReport {
        let componentReports = components.map { $0.report }
        return WorkflowReport(
            id: self.id,
            name: self.name,
            description: self.description,
            state: await self.state,
            executionTime: nil, // Replace with actual total execution time if tracked
            outputs: self.outputs,
            componentReports: componentReports,
            error: nil // Update with error info if applicable
        )
    }
}
