//
//  AnalyzeSentimentMLTask.swift
//  AuroraTaskLibrary
//
//  Created by Dan Murrell Jr on 5/7/25.
//

import Foundation
import AuroraCore
import AuroraML

/**
 `AnalyzeSentimentMLTask` performs sentiment analysis on an array of strings using any `MLServiceProtocol` implementation.

 - **Inputs**
    - `strings`: The list of texts to analyze.
    - `detailed`: Whether to include confidence percentages (defaults to `false`).
    - `positiveThreshold`: Scores above this are “positive” (defaults to `0.1`).
    - `negativeThreshold`: Scores below this are “negative” (defaults to `-0.1`).
 - **Outputs**
    - `sentiments`: A mapping each input string to either:
    - A `String` label (`"positive"|"neutral"|"negative"`) when `detailed == false`
    - A `[String: Any]` with keys:
    - `"sentiment"`: the label
    - `"confidence"`: `Int` percent (0–100)

 ### Example
 ```swift
     let service = TaggingService(
        name: "SentimentTagger",
        schemes: [.sentimentScore],
        unit: .paragraph
     )
     let task = AnalyzeSentimentMLTask(
        mlService: service,
        strings: ["I love this!", "I hate that."],
        detailed: true,
        positiveThreshold: 0.2,
        negativeThreshold: -0.2
     )

 guard case let .task(wrapped) = task.toComponent() else { fatalError() }
 let outputs = try await wrapped.execute()
 // e.g. outputs["sentiments"] == [
 //   "I love this!": ["sentiment":"positive", "confidence":90],
 //   "I hate that.":  ["sentiment":"negative", "confidence":75]
 // ]

 */
public class AnalyzeSentimentMLTask: WorkflowComponent {
    private let task: Workflow.Task

    /**
     - Parameters:
        - name: The name of the task.
        - mlService: The ML service to use for the task.
        - strings: The list of texts to analyze.
        - detailed: Whether to include confidence percentages (defaults to `false`).
        - positiveThreshold: Scores above this are “positive” (defaults to `0.1`).
        - negativeThreshold: Scores below this are “negative” (defaults to `-0.1`).
        - inputs: Additional inputs for the task. Defaults to an empty dictionary.
     */
    public init(
        name: String? = nil,
        mlService: MLServiceProtocol,
        strings: [String]? = nil,
        detailed: Bool = false,
        positiveThreshold: Double = 0.1,
        negativeThreshold: Double = -0.1,
        inputs: [String: Any?] = [:]
    ) {
        self.task = Workflow.Task(
            name: name ?? String(describing: Self.self),
            description: "Analyze sentiment of strings via ML",
            inputs: inputs
        ) { inputs in
            let texts = inputs.resolve(key: "strings", fallback: strings) ?? []
            guard !texts.isEmpty else {
                throw NSError(
                    domain: "AnalyzeSentimentMLTask", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No strings provided for sentiment analysis."]
                )
            }

            let resp = try await mlService.run(
                request: MLRequest(inputs: ["strings": texts])
            )

            guard let tagArrays = resp.outputs["tags"] as? [[Tag]] else {
                throw NSError(
                    domain: "AnalyzeSentimentMLTask", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Missing 'tags' in ML response."]
                )
            }

            var result: [String: Any] = [:]
            for (i, text) in texts.enumerated() {
                let rawScore = tagArrays[i].first?.confidence ?? 0.0

                let label: String
                if rawScore > positiveThreshold {
                    label = "positive"
                } else if rawScore < negativeThreshold {
                    label = "negative"
                } else {
                    label = "neutral"
                }

                if detailed {
                    let pct = Int((abs(rawScore) * 100).rounded())
                    result[text] = [
                        "sentiment": label,
                        "confidence": pct
                    ]
                } else {
                    result[text] = label
                }
            }

            return ["sentiments": result]
        }
    }

    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}

