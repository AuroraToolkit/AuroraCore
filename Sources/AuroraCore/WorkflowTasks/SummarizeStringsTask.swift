//
//  SummarizeStringsTask.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/6/24.
//

import Foundation

/**
    A task that summarizes a list of strings using the LLM service.

 - **Inputs**
    - `summarizer`: The summarizer to be used for the task.
    - `summaryType`: The type of summary to be performed (e.g., context, general text).
    - `SummarizerOptions`: Additional summarizer configuration options (e.g. model, temperature).
 - **Outputs**
    - `summaries`:  The list of summarized strings.

 This task can be integrated in a workflow where context items need to be summarized.
 */
public class SummarizeStringsTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    private let summarizer: SummarizerProtocol
    private let summaryType: SummaryType
    private let strings: [String]

    /**
        Initializes a `SummarizeStringsTask` with the required parameters.

        - Parameters:
            - name: Optionally pass the name of the task.
            - summarizer: The summarizer to be used for the task.
            - summaryType: The type of summary to be performed (e.g., context, general text).
            - strings: The list of strings to be summarized.
            - options: Optional `SummarizerOptions` to provide additional configuration options (e.g., model, temperature).
     */
    public init(
        name: String? = nil,
        summarizer: SummarizerProtocol,
        summaryType: SummaryType,
        strings: [String],
        options: SummarizerOptions? = nil
    ) {
        self.summarizer = summarizer
        self.summaryType = summaryType
        self.strings = strings
        self.task = Workflow.Task(
            name: name,
            description: "Summarize a list of strings using the LLM service",
            inputs: [
                "strings": strings,
                "options": options ?? SummarizerOptions()
            ]
        ) { inputs in
            guard let strings = inputs["strings"] as? [String], !strings.isEmpty else {
                throw NSError(domain: "SummarizeStringsTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "No strings provided for summarization."])
            }

            let options = inputs["options"] as? SummarizerOptions
            let summaries = try await summarizer.summarizeGroup(strings, type: summaryType, options: options)
            return ["summaries": summaries]
        }
    }

    /// Converts this `LoadContextTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
