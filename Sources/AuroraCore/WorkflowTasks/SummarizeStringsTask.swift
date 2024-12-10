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
 - **Outputs**
    - `summaries`:  The list of summarized strings.

 This task can be integrated in a workflow where context items need to be summarized.
 */
public class SummarizeStringsTask: WorkflowTask {
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
     */
    public init(
        name: String? = nil,
        summarizer: SummarizerProtocol,
        summaryType: SummaryType,
        strings: [String]
    ) {
        self.summarizer = summarizer
        self.summaryType = summaryType
        self.strings = strings
        super.init(
            name: name,
            description: "Summarize a list of strings using the LLM service",
            inputs: ["strings": strings]
        )
    }

    public override func execute() async throws -> [String: Any] {
        guard let strings = inputs["strings"] as? [String], !strings.isEmpty else {
            markFailed()
            throw NSError(domain: "SummarizeStringsTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "No strings provided for summarization."])
        }

        let summaries = try await summarizer.summarizeGroup(strings, type: summaryType, options: nil)
        markCompleted()
        return ["summaries": summaries]
    }
}
