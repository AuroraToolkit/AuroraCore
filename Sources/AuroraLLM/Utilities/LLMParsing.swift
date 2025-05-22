//
//  LLMParsing.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/10/25.
//

import Foundation

public extension String {
    /**
        Strips Markdown code block notation from the string, if present.
        Specifically targets blocks starting with "```json" and ending with "```".

        - Returns: The JSON string with the Markdown code block notation removed.
     */
    func stripMarkdownJSON() -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```json") && trimmed.hasSuffix("```") {
            // Remove the first and last lines containing the markdown notation
            var lines = trimmed.components(separatedBy: "\n")
            lines.removeFirst() // Remove ```json
            lines.removeLast() // Remove ```
            return lines.joined(separator: "\n")
        }
        return self
    }

    /**
     Extracts thought blocks delimited by <think>...</think> and strips them and any Markdown JSON fences.
        - Returns: A tuple of thought strings and the cleaned JSON string.
     */
    func extractThoughtsAndStripJSON() -> (thoughts: [String], jsonBody: String) {
        let pattern = "(?s)<think>(.*?)</think>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
            return ([], trimmed)
        }

        let nsrange = NSRange(self.startIndex..<self.endIndex, in: self)
        // Find all the <think>…</think> matches
        let matches = regex.matches(in: self, options: [], range: nsrange)
        var thoughts: [String] = []
        for m in matches {
            if let r = Range(m.range(at: 1), in: self) {
                thoughts.append(self[r].trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        // Strip out all <think>…</think> blocks
        let withoutThinks = regex.stringByReplacingMatches(
            in: self,
            options: [],
            range: nsrange,
            withTemplate: ""
        )
        let trimmed = withoutThinks.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = trimmed.stripMarkdownJSON().trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = stripped.firstIndex(of: "{"), let end = stripped.lastIndex(of: "}") {
            let jsonBody = String(stripped[start...end])
            return (thoughts, jsonBody)
        }
        return (thoughts, stripped)
    }
}
