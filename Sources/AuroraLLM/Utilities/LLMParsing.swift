//
//  LLMParsing.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/10/25.
//

extension String {
    /// Strips Markdown code block notation from the string, if present.
    /// Specifically targets blocks starting with "```json" and ending with "```".

    /**
        Strips Markdown code block notation from the string, if present.
        Specifically targets blocks starting with "```json" and ending with "```".

        - Returns: The JSON string with the Markdown code block notation removed.
     */
    public func stripMarkdownJSON() -> String {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```json") && trimmed.hasSuffix("```") {
            // Remove the first and last lines containing the markdown notation
            var lines = trimmed.components(separatedBy: "\n")
            lines.removeFirst() // Remove ```json
            lines.removeLast()  // Remove ```
            return lines.joined(separator: "\n")
        }
        return self
    }
}
