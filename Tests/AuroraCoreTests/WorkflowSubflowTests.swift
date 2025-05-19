//
//  WorkflowSubflowTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 2/22/25.
//

import XCTest
@testable import AuroraCore

final class WorkflowSubflowTests: XCTestCase {

    func testSubflowReportGeneration() async throws {
        // Create a subflow with two tasks.
        let subflow = Workflow.Subflow(name: "Subflow Test", description: "A test subflow") {
            Workflow.Task(name: "Task 1", description: "First task") { _ in
                return ["result": "Task 1 complete"]
            }
            Workflow.Task(name: "Task 2", description: "Second task") { _ in
                return ["result": "Task 2 complete"]
            }
        }

        // Build a parent workflow that includes the subflow.
        var workflow = Workflow(name: "Parent Workflow", description: "Workflow with a subflow") {
            subflow.toComponent()
        }

        // Run the workflow.
        await workflow.start()

        // Generate the overall workflow report.
        let report = await workflow.generateReport()

        // Check that the parent workflow outputs have been merged with the subflow's outputs.
        // We assume that task outputs are merged using keys like "Task 1.result" and "Task 2.result".
        XCTAssertNotNil(workflow.outputs["Task 1.result"], "Workflow outputs should include subflow's Task 1 output")
        XCTAssertNotNil(workflow.outputs["Task 2.result"], "Workflow outputs should include subflow's Task 2 output")

        // Check that the subflow report is present among the component reports.
        guard let subflowReport = report.componentReports.first(where: { $0.type == "Subflow" }) else {
            XCTFail("Subflow report not found")
            return
        }

        // Verify subflow's final state and that it has two child reports.
        XCTAssertEqual(subflowReport.state, .completed, "Subflow should be completed")
        XCTAssertEqual(subflowReport.childReports?.count, 2, "Subflow should have 2 child reports")

        // Optionally, print the report for manual verification.
        print(report.printedReport(compact: true))
    }
}
