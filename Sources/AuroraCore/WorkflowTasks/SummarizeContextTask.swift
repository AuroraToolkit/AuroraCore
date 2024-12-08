//
//  SummarizeTask.swift
//  
//
//  Created by Dan Murrell Jr on 9/2/24.
//

import Foundation

/**
 `SummarizeContextTask` is responsible for summarizing context items within a `ContextController` using the connected LLM service.

 - **Inputs**
    - `ContextController`: The context controller containing the context to be summarized.
    - `SummaryType`: The type of summary to be performed (e.g., context, general text).
 - **Outputs**
    - `summarizedContext`: The context containing the summarized content.

 This task can be integrated in a workflow where context items need to be summarized.
 */
public class SummarizeContextTask: WorkflowTask {

    private let contextController: ContextController
    private let summaryType: SummaryType

    /**
     Initializes a new `SummarizeContextTask` instance.

     - Parameters:
        - name: Optionally pass the name of the task.
        - contextController: The `ContextController` instance containing the context to be summarized.
        - summaryType: The type of summary to be performed (`single` or `multiple`).
     */
    public init(
        name: String? = nil,
        contextController: ContextController,
        summaryType: SummaryType = .multiple
    ) {
        self.contextController = contextController
        self.summaryType = summaryType
        super.init(
            name: name,
            description: "Summarize the content in the context controller"
        )
    }

    /**
     Executes the summarization task with options, summarizing the context items and storing the result.

     - Parameter with options: Optional `SummarizerOptions` to provide additional configuration options (e.g., model, temperature).

     - Throws: An error if the summarization fails.
     - Returns: A dictionary containing the summarized context.
     */
    public func execute(with options: SummarizerOptions? = nil) async throws -> [String: Any] {
        // Retrieve all context items to be summarized
        let itemsToSummarize = contextController.getItems().map { $0.text }

        // If there are no items, do nothing
        guard !itemsToSummarize.isEmpty else {
            return [:]
        }

        // Summarize the items based on the summary type
        let summarizer = contextController.getSummarizer()
        switch summaryType {
        case .single:
            // Create a single combined summary
            let combinedSummary = try await summarizer.summarize(itemsToSummarize.joined(separator: "\n"), options: options)
            contextController.addItem(content: combinedSummary, isSummary: true)
            return ["summarizedContext": [combinedSummary]]

        case .multiple:
            // Create individual summaries for each item
            let summaries = try await summarizer.summarizeGroup(itemsToSummarize, type: .multiple, options: options)
            summaries.forEach { summary in
                contextController.addItem(content: summary, isSummary: true)
            }
            return ["summarizedContext": summaries]
        }
    }

    /**
     Executes the summarization task, summarizing the context items and storing the result.

     - Throws: An error if the summarization fails.
     - Returns: A dictionary containing the summarized context.
     */
    public override func execute() async throws -> [String: Any] {
        return try await execute(with: nil)
    }
}
