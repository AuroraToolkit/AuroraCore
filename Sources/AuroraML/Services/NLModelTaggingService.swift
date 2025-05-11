//
//  NLModelTaggingService.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/9/25.
//

import Foundation
import NaturalLanguage
import AuroraCore

/**
 `NLModelTaggingService` implements `MLServiceProtocol` using Apple's `NLModel` text classifiers.

 It tokenizes each input string into tokens via `NLTokenizer`, uses the provided `NLModel` to predict a label and optional confidence for each token, and returns a two-dimensional array of `Tag` objects, where each inner array corresponds to the tags for one input string.

 - **Inputs**
    - `strings`: An array of `String` texts to tag.
 - **Outputs**
    - `tags`: A two-dimensional array `[[Tag]]`, where each inner array corresponds to the tags for one input string.

 **Note**: Your Core ML model must be a compiled text classifier loaded into an `NLModel` (e.g. `NLModel(contentsOf: myModelURL)`).

 ### Example
 ```swift
 // Load a compiled Core ML text classifier:
 let model = try! NLModel(contentsOf: URL(fileURLWithPath: "TextClassifier.mlmodelc"))
 let service = NLModelTaggingService(
    name: "TextClassifier",
    model: model,
    scheme: "TextClassifier",
    unit: .word
 )

 let task = TaggingTask(
 service: service,
 strings: ["I love Swift!", "This is okay."]
 )

 // Execute:
 guard case let .task(wrapped) = task.toComponent() else { return }
 let outputs = try await wrapped.execute()
 let tags = outputs["tags"] as? [[Tag]]
 print(tags)
 */
public final class NLModelTaggingService: MLServiceProtocol {
    public var name: String
    private let model: NLModel
    private let scheme: String
    private let tokenizer: NLTokenizer
    private let logger: CustomLogger?

    /**
     - Parameters:
     - name: Identifier for this service.
     - model: A compiled `NLModel` that takes a single text feature `"text"` and outputs a `"label"` string and an optional `"confidence"` double.
     - scheme: The tag scheme identifier to set on each `Tag`.
     - unit: Tokenization granularity (`.word`, `.sentence`, or `.paragraph`).
     - logger: Optional logger for debugging.
     */
    public init(
        name: String,
        model: NLModel,
        scheme: String,
        unit: NLTokenUnit = .word,
        logger: CustomLogger? = nil
    ) {
        self.name = name
        self.model = model
        self.scheme = scheme
        self.tokenizer = NLTokenizer(unit: unit)
        self.logger = logger
    }

    public func run(request: MLRequest) async throws -> MLResponse {
        guard let texts = request.inputs["strings"] as? [String] else {
            logger?.error("Missing 'strings' input", category: name)
            throw NSError(domain: name, code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Input 'strings' missing"])
        }

        var allTags = [[Tag]]()

        for text in texts {
            tokenizer.string = text
            var tagsForText: [Tag] = []

            tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
                let token = String(text[tokenRange])
                let start = text.distance(from: text.startIndex, to: tokenRange.lowerBound)
                let length = text.distance(from: tokenRange.lowerBound, to: tokenRange.upperBound)

                // Query NLModel for top hypothesis (label + confidence)
                let hypos = model.predictedLabelHypotheses(for: token, maximumCount: 1)
                let (label, confidence) = hypos.first
                    ?? (model.predictedLabel(for: token) ?? "", 0.0)

                logger?.debug("[\(name)] token='\(token)' → \(label) @\(confidence)", category: name)

                tagsForText.append(
                    Tag(
                        token: token,
                        label: label,
                        scheme: scheme,
                        confidence: confidence,
                        start: start,
                        length: length
                    )
                )
                return true
            }

            allTags.append(tagsForText)
        }

        return MLResponse(outputs: ["tags": allTags], info: nil)
    }
}
