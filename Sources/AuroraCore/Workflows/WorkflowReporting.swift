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
    public let type: String
    public let state: Workflow.State
    public let executionTime: TimeInterval? // in seconds
    public let outputs: [String: Any]?
    public let childReports: [WorkflowComponentReport]?
    public let error: Error?

    public init(
        id: UUID,
        name: String,
        description: String,
        type: String,
        state: Workflow.State,
        executionTime: TimeInterval? = nil,
        outputs: [String: Any]? = nil,
        childReports: [WorkflowComponentReport]? = nil,
        error: Error? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
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
        if let details = self.detailsHolder.details {
            return WorkflowComponentReport(
                id: self.id,
                name: self.name,
                description: self.description,
                type: "Task",
                state: details.state,
                executionTime: details.executionTime,
                outputs: details.outputs,
                childReports: nil,
                error: details.error
            )
        } else {
            return WorkflowComponentReport(
                id: self.id,
                name: self.name,
                description: self.description,
                type: "Task",
                state: .notStarted,
                executionTime: nil,
                outputs: nil,
                childReports: nil,
                error: nil
            )
        }
    }
}

extension Workflow.TaskGroup: WorkflowReportable {
    public func generateReport() -> WorkflowComponentReport {
        let childReports = self.tasks.map { $0.generateReport() }
        if let details = self.detailsHolder.details {
            return WorkflowComponentReport(
                id: self.id,
                name: self.name,
                description: self.description,
                type: "TaskGroup",
                state: details.state,
                executionTime: details.executionTime,
                outputs: details.outputs,
                childReports: childReports,
                error: details.error
            )
        } else {
            return WorkflowComponentReport(
                id: self.id,
                name: self.name,
                description: self.description,
                type: "TaskGroup",
                state: .notStarted,
                executionTime: nil,
                outputs: nil,
                childReports: childReports,
                error: nil
            )
        }
    }
}

extension Workflow.Subflow: WorkflowReportable {
    public func generateReport() -> WorkflowComponentReport {
        // Map properties from the wrapped Workflow into a WorkflowComponentReport.
        return WorkflowComponentReport(
            id: self.workflow.id,
            name: self.workflow.name,
            description: self.workflow.description,
            type: "Subflow",
            state: self.workflow.detailsHolder.details?.state ?? .notStarted,
            executionTime: self.workflow.detailsHolder.details?.executionTime ?? 0.0,
            outputs: self.workflow.outputs,
            childReports: self.workflow.componentsManager.completedComponents.map { $0.report },
            error: nil
        )
    }
}

extension Workflow.Logic: WorkflowReportable {
    public func generateReport() -> WorkflowComponentReport {
        if let details = self.detailsHolder.details {
            return WorkflowComponentReport(
                id: self.id,
                name: self.name,
                description: self.description,
                type: "Logic",
                state: details.state,
                executionTime: details.executionTime,
                outputs: details.outputs,
                childReports: nil,
                error: details.error
            )
        } else {
            return WorkflowComponentReport(
                id: self.id,
                name: self.name,
                description: self.description,
                type: "Logic",
                state: .notStarted,
                executionTime: nil,
                outputs: nil,
                childReports: nil,
                error: nil
            )
        }
    }
}

extension Workflow.Trigger: WorkflowReportable {
    public func generateReport() -> WorkflowComponentReport {
        if let details = self.detailsHolder.details {
            return WorkflowComponentReport(
                id: self.id,
                name: self.name,
                description: self.description,
                type: "Trigger",
                state: details.state,
                executionTime: details.executionTime,
                outputs: details.outputs,
                childReports: nil,
                error: details.error
            )
        } else {
            return WorkflowComponentReport(
                id: self.id,
                name: self.name,
                description: self.description,
                type: "Trigger",
                state: .notStarted,
                executionTime: nil,
                outputs: nil,
                childReports: nil,
                error: nil
            )
        }
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
        case .subflow(let subflow):
            return subflow.generateReport()
        case .logic(let logic):
            return logic.generateReport()
        case .trigger(let trigger):
            return trigger.generateReport()
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
    public let error: Error?

    public init(
        id: UUID,
        name: String,
        description: String,
        state: Workflow.State,
        executionTime: TimeInterval? = nil,
        outputs: [String: Any]? = nil,
        componentReports: [WorkflowComponentReport] = [],
        error: Error? = nil
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
        let componentReports = componentsManager.completedComponents.map { $0.report }
        let executionTime = componentsManager.completedComponents.reduce(0.0) { $0 + $1.executionTime }
        return WorkflowReport(
            id: self.id,
            name: self.name,
            description: self.description,
            state: await self.state,
            executionTime: executionTime,
            outputs: self.outputs,
            componentReports: componentReports,
            error: nil // Update with error info if applicable
        )
    }
}

// MARK: - Report Printing Extensions

extension WorkflowComponentReport {

    /**
    Returns a formatted string representation of the report.

    - Parameters:
        - compact: When true, prints child reports in a condensed format.
        - showOutputs: When true, includes the outputs in the report.
        - indent: A string to prepend to each line (for nested reports).
     */
    public func printedReport(compact: Bool = false, showOutputs: Bool = true, indent: String = "") -> String {
        var output = ""
        output += "\(indent)Type: \(type)\n" // NEW
        output += "\(indent)ID: \(id)\n"
        output += "\(indent)Name: \(name)\n"
        output += "\(indent)Description: \(description)\n"
        output += "\(indent)State: \(state)\n"
        if let execTime = executionTime {
            output += "\(indent)Execution Time: \(String(format: "%.2f", execTime)) sec\n"
        }
        if showOutputs, let outs = outputs, !outs.isEmpty {
            output += "\(indent)Outputs: \(outs)\n"
        }
        if let error = error {
            output += "\(indent)Error: \(error.localizedDescription)\n"
        }
        if let children = childReports, !children.isEmpty {
            output += "\(indent)Child Reports:\n"
            for child in children {
                if compact {
                    output += "\(indent)  - \(child.name) (\(child.state))\n"
                } else {
                    output += child.printedReport(compact: false, showOutputs: showOutputs, indent: indent + "   ") + "\n"
                }
            }
        }
        return output
    }
}

extension WorkflowReport {

    /**
    Returns a formatted string representation of the overall workflow report.

    - Parameters:
        - compact: When true, child components are printed in a condensed format.
        - showOutputs: When true, includes the outputs in the report.
     */
    public func printedReport(compact: Bool = false, showOutputs: Bool = true) -> String {
        var output = "Workflow Report:\n"
        output += "ID: \(id)\n"
        output += "Name: \(name)\n"
        output += "Description: \(description)\n"
        output += "State: \(state)\n"
        if let execTime = executionTime {
            output += "Total Execution Time: \(String(format: "%.2f", execTime)) sec\n"
        }
        if showOutputs, let outs = outputs, !outs.isEmpty {
            output += "Workflow Outputs: \(outs)\n"
        }
        if let error = error {
            output += "Workflow Error: \(error.localizedDescription)\n"
        }
        if !componentReports.isEmpty {
            output += "Component Reports:\n"
            for component in componentReports {
                output += component.printedReport(compact: compact, showOutputs: showOutputs, indent: "   ") + "\n"
            }
        }
        return output
    }
}
