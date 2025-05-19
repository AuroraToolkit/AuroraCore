//
//  Tag.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/6/25.
//

import Foundation

/**
 A single tagged span in an input string, produced by `TaggingService` or other tagging ML services.

 - Use Cases:
 - Sentiment tagging: each word or phrase tagged with a sentiment label and optional score.
 - Entity extraction: tokens tagged as `PERSON`, `ORG`, `LOCATION`, etc., with confidences.
 - Keyword or lemma tagging: parts of speech, lemmas, or custom categories.
 - Any other token-level or span-level ML tagging.

 - Example:
 ```swift
 let example = "I love Swift!"
 let tag = Tag(
    token: "love",
    label: "Positive",
    scheme: "sentimentScore",
    confidence: 0.95,
    start: 2,
    length: 4
 )
 ```

 */
public struct Tag: Equatable {
    /// The exact substring from the source text that was tagged.
    public let token: String

    /// The label or category assigned to `token` (e.g. `"positive"`, `"PERSON"`).
    public let label: String

    /// Identifier of the tagging scheme (e.g. `"sentimentScore"`, `"nameType"`, `"lemma"`).
    public let scheme: String

    /// Optional confidence or score associated with this tag.
    /// For NLTagger sentimentScore schemes this will be –1.0…1.0; for others, 0.0…1.0.
    public let confidence: Double?

    /// The start of the tagged token in the source string.
    public let start: Int

    /// The length  of the tagged token in the source string.
    public let length: Int

    /**
     Creates a new `Tag`.

     - Parameters:
        - token: The substring that was tagged.
        - label: The tag label or category.
        - scheme: The tagging scheme identifier.
        - confidence: An optional confidence score (default: `nil`).
        - start: The starting index of the tagged token in the source string.
        - length: The length of the tagged token in the source string.
     */
    public init(
        token: String,
        label: String,
        scheme: String,
        confidence: Double? = nil,
        start: Int,
        length: Int
    ) {
        self.token = token
        self.label = label
        self.scheme = scheme
        self.confidence = confidence
        self.start = start
        self.length = length
    }
}
