//
//  SummarizeTask.swift
//  
//
//  Created by Dan Murrell Jr on 9/2/24.
//

import Foundation

/**
 `SummarizeTask` is responsible for summarizing context items within a `ContextController` using the connected LLM service.
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
    public override func execute() async throws {
        // Retrieve all context items to be summarized
        let itemsToSummarize = contextController.getItems()

        // If there are no items, do nothing
        guard !itemsToSummarize.isEmpty else {
            return
        }

        // Summarize the items
        let summaries = try await contextController.getSummarizer().summarizeGroup(itemsToSummarize.map { $0.text }, type: summaryType)

        // Store the summaries in the context
        contextController.addItem(content: summaries, isSummary: true)

        // Save the summarized context to outputs for further use
        outputs["summarizedContext"] = contextController.getContext()
    }
}
