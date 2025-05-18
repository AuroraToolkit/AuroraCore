//
//  ClassificationService.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/9/25.
//

import Foundation
import NaturalLanguage
import AuroraCore

/**
 `ClassificationService` implements `MLServiceProtocol` using Apple's `NLModel` text classifiers.

 It classifies each input string using the provided `NLModel` to predict a label and optional confidence, and returns an array of `Tag` objects, where each  tag corresponds to an input string.

 - **Inputs**
    - `strings`: An array of `String` texts to tag.
 - **Outputs**
    - `tags`: A `Tag` array, where each tag corresponds to an input string. Each `Tag` includes:
        - `token`: the substring that was tagged
        - `label`: the tag or category
        - `scheme`: the tagging scheme identifier
        - `confidence`: optional confidence score
        - `start`: starting index of the tagged token in the source string
        - `length`: length of the tagged token in the source string

 **Note**: Your Core ML model must be a compiled text classifier loaded into an `NLModel` (e.g. `NLModel(contentsOf: myModelURL)`).

 ### Example
 ```swift
 // Load a compiled Core ML text classifier:
 let model = try! NLModel(contentsOf: URL(fileURLWithPath: "TextClassifier.mlmodelc"))
 let service = ClassificationService(
    name: "TextClassifier",
    model: model,
    scheme: "TextClassifier",
    maxResults: 3,
    logger: CustomLogger.shared
 )

 let strings = ["I love Swift!", "This is okay."]
 let request = MLRequest(inputs: ["strings": strings])

 // Execute:
 let outputs = try await service.run(request: request)
 let tags = outputs["tags"] as? [Tag]
 for tag in tags {
     print("\(tag.token) → \(tag.label) @\(tag.confidence ?? 0)")
 }
 ```
 */
public final class ClassificationService: MLServiceProtocol {
    public var name: String
    private let model: NLModel
    private let scheme: String
    private let maxResults: Int
    private let logger: CustomLogger?

    /**
     - Parameters:
        - name: Identifier for this service.
        - model: A compiled `NLModel` text‐classifier.
        - scheme: The tag scheme identifier to set on each `Tag`.
        - maxResults: How many top labels to return per input string.
        - logger: Optional logger for debugging.
     */
    public init(
        name: String,
        model: NLModel,
        scheme: String,
        maxResults: Int = 3,
        logger: CustomLogger? = nil
    ) {
        self.name = name
        self.model = model
        self.scheme = scheme
        self.maxResults = maxResults
        self.logger = logger
    }

    public func run(request: MLRequest) async throws -> MLResponse {
        guard let texts = request.inputs["strings"] as? [String] else {
            logger?.error("Missing 'strings' input", category: name)
            throw NSError(domain: name, code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Input 'strings' missing"])
        }

        var tags: [Tag] = []

        for text in texts {
            let hypos = model.predictedLabelHypotheses(
                for: text,
                maximumCount: maxResults
            )

            for (label, score) in hypos {
                if let logger {
                    let loggedText = text.count > 15 ? "\(text.prefix(15))..." : text
                    logger.debug("[\(name)] \(loggedText)) → \(label) @\(score)", category: name)
                }
                let tag = Tag(
                    token: text,
                    label: label,
                    scheme: scheme,
                    confidence: score,
                    start: 0,
                    length: text.count
                )
                tags.append(tag)
            }
        }

        return MLResponse(outputs: ["tags": tags], info: nil)
    }
}
