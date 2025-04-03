//
//  SummarizeTextSkill.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 3/26/25.
//

import Foundation
import AuroraCore
import AuroraTaskLibrary
import AuroraLLM

/**
 A simple agent skill that summarizes a list of strings.

 Instead of using the query parameter, this skill uses an internal collection
 of strings that are provided at initialization.
 */
public struct SummarizeTextSkill: AgentSkill {
    public let id: UUID
    public let name: String
    public let description: String
    
    /// The strings to summarize.
    public let strings: [String]
    
    /// The summarizer to use. (In a real implementation you might inject this,
    /// here we create one for simplicity.)
    public let summarizer: SummarizerProtocol

    /**
     Initializes a new SummarizeTextSkill.
     
     - Parameters:
        - strings: The list of strings to summarize.
        - name: The name of the skill (default is "Summarize Text Skill").
        - description: A description of what the skill does.
        - summarizer: The summarizer to use (default uses an OpenAIService with a dummy API key).
     */
    public init(
        strings: [String],
        name: String = "Summarize Text Skill",
        description: String = "Summarizes a list of strings using an LLM summarizer",
        summarizer: SummarizerProtocol = Summarizer(llmService: OpenAIService(apiKey: "your-api-key"))
    ) {
        self.id = UUID()
        self.strings = strings
        self.name = name
        self.description = description
        self.summarizer = summarizer
    }
    
    /**
     Executes the skill with a given query and memory.
     
     In this skill the `query` parameter is ignored and the stored `strings` are summarized.
     
     - Parameters:
        - query: An optional query string (ignored).
        - memory: An optional shared agent memory (ignored).
     
     - Returns: A summary string of the provided strings.
     
     - Throws: An error if no strings are provided or if summarization fails.
     */
    public func execute(query: String, memory: AgentMemory?) async throws -> String {
        guard !strings.isEmpty else {
            throw NSError(domain: "SummarizeTextSkill", code: 1, userInfo: [NSLocalizedDescriptionKey: "No strings provided for summarization."])
        }
        
        // Build a workflow that wraps a SummarizeStringsTask.
        var workflow = Workflow(name: "SummarizeTextWorkflow", description: "Workflow to summarize text") {
            SummarizeStringsTask(
                summarizer: summarizer,
                summaryType: .single,
                strings: strings
            )
        }
        
        // Execute the workflow.
        await workflow.start()
        
        // Extract and return the summary.
        if let summaries = workflow.outputs["SummarizeStringsTask.summaries"] as? [String],
           let summary = summaries.first {
            return summary
        } else {
            throw NSError(domain: "SummarizeTextSkill", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to generate summary"])
        }
    }
}
