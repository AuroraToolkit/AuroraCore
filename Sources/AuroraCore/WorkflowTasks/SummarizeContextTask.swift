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
    - `SummarizerOptions`: Additional summarizer configuration options (e.g. model, temperature).
 - **Outputs**
    - `summarizedContext`: The context containing the summarized content.

 This task can be integrated in a workflow where context items need to be summarized.
 */
public class SummarizeContextTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    private let contextController: ContextController
    private let summaryType: SummaryType

    /**
     Initializes a new `SummarizeContextTask` instance.

     - Parameters:
        - name: Optionally pass the name of the task.
        - contextController: The `ContextController` instance containing the context to be summarized.
        - summaryType: The type of summary to be performed (`single` or `multiple`).
        - options:Optional `SummarizerOptions` to provide additional configuration options (e.g., model, temperature).
     */
    public init(
        name: String? = nil,
        contextController: ContextController,
        summaryType: SummaryType = .multiple,
        options: SummarizerOptions? = nil
    ) {
        self.contextController = contextController
        self.summaryType = summaryType
        self.task = Workflow.Task(
            name: name,
            description: "Summarize the content in the context controller",
            inputs: ["options": options ?? SummarizerOptions()]
        ) { inputs in
            // Retrieve all context items to be summarized
            let itemsToSummarize = contextController.getItems().map { $0.text }

            // If there are no items, do nothing
            guard !itemsToSummarize.isEmpty else {
                return [:]
            }

            let options = inputs["options"] as? SummarizerOptions

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
    }

    /// Converts this `LoadContextTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
