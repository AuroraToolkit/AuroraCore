//
//  SummarizeTask.swift
//  
//
//  Created by Dan Murrell Jr on 9/2/24.
//

import Foundation

/**
 `SummarizeTask` is responsible for summarizing context items within a `ContextController` using the connected LLM service.

 - **Inputs**
    - `ContextController`: The context controller containing the context to be summarized.
    - `SummaryType`: The type of summary to be performed (e.g., context, general text).
 - **Outputs**
    - `summarizedContext`: The context containing the summarized content.

 This task can be integrated in a workflow where context items need to be summarized.
 */
public class SummarizeTask: WorkflowTask {

    private let contextController: ContextController
    private let summaryType: SummaryType

    /**
     Initializes a new `SummarizeTask` instance.

     - Parameters:
        - contextController: The `ContextController` instance containing the context to be summarized.
        - summaryType: The type of summary to be performed (e.g., context, general text).
     */
    public init(contextController: ContextController, summaryType: SummaryType) {
        self.contextController = contextController
        self.summaryType = summaryType
        super.init(name: "Summarize Context", description: "Summarize the content in the context controller")
    }

    /**
     Executes the summarization task, summarizing the context items and storing the result.

     - Throws: An error if the summarization fails.
     */
    public override func execute() async throws -> [String: Any] {
        return try await execute(with: nil)
    }

    /**
     Executes the summarization task with options, summarizing the context items and storing the result.

     - Parameter with options: Optional `SummarizerOptions` to provide additional configuration options (e.g. model, temperature).
     
     - Throws: An error if the summarization fails.
     */
    public func execute(with options: SummarizerOptions? = nil) async throws -> [String: Any] {
        // Retrieve all context items to be summarized
        let itemsToSummarize = contextController.getItems()

        // If there are no items, do nothing
        guard !itemsToSummarize.isEmpty else {
            return [:]
        }

        // Summarize the items
        let summaries = try await contextController.getSummarizer().summarizeGroup(itemsToSummarize.map { $0.text }, type: summaryType, options: nil)

        // Store the summaries in the context
        contextController.addItem(content: summaries, isSummary: true)

        return ["summarizedContext": contextController.getContext()]
    }
}
