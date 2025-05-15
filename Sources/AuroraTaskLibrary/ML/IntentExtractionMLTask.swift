//
//  IntentExtractionMLTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/14/25.
//

import Foundation
import AuroraCore
import AuroraML
import NaturalLanguage

/**
 `IntentExtractionMLTask` wraps any `MLServiceProtocol` that extracts user intents (and optional parameters) from text into a WorkflowComponent.

 - **Inputs**
    - `strings`: `[String]` of texts to extract intents from.
 - **Outputs**
    - `intents`: `[[String: Any]]` — an array (per input string) of intent dictionaries.

 Each intent dictionary should include at minimum:
 - `"name"`: the intent identifier (e.g. `"setReminder"`)
 - `"confidence"`: `Double?` (optional)
 - `"parameters"`: `[String: Any]?` (optional map of slot names to values)

 ### Example
 ```swift
 let mockIntents: [[String: Any]] = [
    ["name":"setReminder","confidence":0.98,"parameters":["time":"5pm","task":"walk dog"]],
    ["name":"getWeather","confidence":0.85,"parameters":["city":"San Francisco"]]
 ]
 let service = MockMLService(
    name: "intent-mock",
    response: MLResponse(outputs: ["intents": mockIntents], info: nil)
 )
 let task = IntentExtractionMLTask(
    service: service,
    strings: ["Remind me at 5pm to walk the dog","What's the weather in San Francisco?"],
    model: model
 )

 guard case let .task(wrapped) = task.toComponent() else { fatalError() }
 let outputs = try await wrapped.execute()
 let extracted = outputs["intents"] as! [[String: Any]]
 print(extracted)
 ```
 */
public class IntentExtractionMLTask: WorkflowComponent {
    private let task: Workflow.Task

    /**
     - Parameters:
        - name: Optional override for the workflow task name.
        - description: Optional override for description.
        - model: The `NLModel` to use for intent extraction.
        - maxResults: The maximum number of results to return.
        - strings: The texts to extract intents from.
        - inputs: Any additional inputs (fallbacks).
     */
    public init(
        name: String? = nil,
        description: String? = nil,
        model: NLModel,
        slotSchemes: [NLTagScheme] = [.nameType, .lexicalClass],
        maxResults: Int = 3,
        strings: [String]? = nil,
        inputs: [String: Any?] = [:]
    ) {
        let intentService = IntentExtractionService(
            name: name ?? "IntentExtractionService",
            model: model,
            maxResults: maxResults,
            logger: CustomLogger.shared
        )
        let slotService = TaggingService(
            name: "IntentSlotTagger",
            schemes: slotSchemes,
            unit: .word,
            options: [.omitPunctuation, .omitWhitespace],
            logger: CustomLogger.shared
        )
        self.task = Workflow.Task(
            name: name ?? String(describing: Self.self),
            description: description ?? "Extract intents + parameters from text",
            inputs: inputs
        ) { inputs in
            let texts = inputs.resolve(key: "strings", fallback: strings) ?? []
            guard !texts.isEmpty else {
                throw NSError(
                    domain: "IntentExtractionMLTask",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No strings provided"]
                )
            }

            var allResults: [[String: Any]] = []

            for text in texts {
                let intentResponse = try await intentService.run(
                    request: MLRequest(inputs: ["strings": [text]])
                )
                let slotsResponse = try await slotService.run(
                    request: MLRequest(inputs: ["strings": [text]])
                )

                guard let intents = intentResponse.outputs["intents"] as? [[String: Any]] else {
                    throw NSError(
                        domain: "IntentExtractionMLTask",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Missing 'intents' in ML response"]
                    )
                }

                guard let slotTags = slotsResponse.outputs["tags"] as? [[Tag]] else {
                    throw NSError(
                        domain: "IntentExtractionMLTask",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Missing 'slots' in ML response"]
                    )
                }
                /// Build a lookup dictionary of slot tags to values
                let slots = slotTags
                    .flatMap { $0 }
                    .reduce(into: [String: String]()) { result, tag in
                        result[tag.scheme] = tag.token
                    }

                /// Combine the intents and slots into a single dictionary
                for intent in intents {
                    var combinedIntent = intent
                    combinedIntent["parameters"] = slots
                    allResults.append(combinedIntent)
                }
            }

            return ["intents": allResults]
        }
    }

    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
