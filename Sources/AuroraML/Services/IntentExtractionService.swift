//
//  IntentExtractionService.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/14/25.
//

import Foundation
import AuroraCore
import NaturalLanguage

/**
 `IntentExtractionService` uses a `ClassificationService` to extract one or more intents from input text, returning a structured list of intent dictionaries.

 - **Inputs**
    - `strings`: `[String]` — one or more texts to classify into intents.
 - **Outputs**
    - `intents`: `[[String: Any]]` — an array of intent dictionaries for each string, each containing:
        - `name`: `String` — the predicted intent label.
        - `confidence`: `Double` — the confidence score for that intent.

 You can configure the maximum number of intents returned via the `maxResults` parameter.
 */
public final class IntentExtractionService: MLServiceProtocol {
    public var name: String

    private let classifier: ClassificationService

    /**
     - Parameters:
     - name: Optionally pass the name of the service, defaults to "IntentExtractionService".
     - model: A compiled `NLModel` trained to predict intents (e.g. “playMusic”, “setTimer”).
     - maxResults: How many top intents to return.
     - logger: Optional logger for debug.
     */
    public init(
        name: String = "IntentExtractionService",
        model: NLModel,
        maxResults: Int = 3,
        logger: CustomLogger? = nil
    ) {
        self.name = name
        self.classifier = ClassificationService(
            name: "IntentExtraction",
            model: model,
            scheme: "intent",
            maxResults: maxResults,
            logger: logger
        )
    }

    public func run(request: MLRequest) async throws -> MLResponse {
        let resp = try await classifier.run(request: request)
        // classifier returns MLResponse.outputs["tags"] as [Tag]
        guard let tags = resp.outputs["tags"] as? [Tag] else {
            throw NSError(
                domain: name,
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Missing 'tags' in classification response"]
            )
        }

        // Now reshape into an "intents" array of dictionaries
        let intents: [[String: Any]] = tags.map { tag in
            [
                "name": tag.label,
                "confidence": tag.confidence ?? 0
            ]
        }

        return MLResponse(outputs: ["intents": intents], info: nil)
    }
}
