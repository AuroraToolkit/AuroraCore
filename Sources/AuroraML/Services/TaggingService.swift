//
//  TaggingService.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/7/25.
//

import Foundation
import NaturalLanguage
import AuroraCore

/**
 A generic NLTagger-backed service for tagging text.

 Uses Apple’s Natural Language `NLTagger` under the hood to produce token-level `Tag` objects for one or more schemes.

 - **Inputs**
    - `strings`: `[String]` of texts to tag.
 - **Outputs**
    - `tags`: `[[Tag]]` — an array (per input string) of `Tag` arrays.

 ### Notes
 - This service supports multiple `NLTagScheme`s. It will enumerate each configured scheme and append all resulting `Tag` objects.
 - For the `.sentimentScore` scheme, `Tag.confidence` will be populated with the numeric score (-1.0…1.0). For other schemes, `confidence` remains `nil`.
 */
public final class TaggingService: MLServiceProtocol {
    public var name: String
    private let schemes: [NLTagScheme]
    private let unit: NLTokenUnit
    private let options: NLTagger.Options
    private let logger: CustomLogger?

    /**
     Initializes a new `TaggingService`.

     - Parameters:
       - name: Identifier for this service (default: `"TaggingService"`).
       - schemes: One or more `NLTagScheme` values (e.g. `[.nameType]`, `[.sentimentScore]`).
       - unit: Tokenization granularity (`.word`, `.sentence`, `.paragraph`).
       - options: `NLTagger.Options` (e.g. `.omitWhitespace`, `.omitPunctuation`).
       - logger: Optional logger for debug/info.
     */
    public init(
        name: String = "TaggingService",
        schemes: [NLTagScheme],
        unit: NLTokenUnit = .word,
        options: NLTagger.Options = [.omitWhitespace, .omitPunctuation],
        logger: CustomLogger? = nil
    ) {
        self.name = name
        self.schemes = schemes
        self.unit = unit
        self.options = options
        self.logger = logger
    }

    public func run(request: MLRequest) async throws -> MLResponse {
        guard let texts = request.inputs["strings"] as? [String] else {
            logger?.error("Missing 'strings' input", category: name)
            throw NSError(
                domain: name,
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Input 'strings' missing"]
            )
        }

        var allTags: [[Tag]] = []
        let tagger = NLTagger(tagSchemes: schemes)

        for text in texts {
            tagger.string = text
            var tagsForText: [Tag] = []
            let fullRange = text.startIndex..<text.endIndex

            for scheme in schemes {
                tagger.enumerateTags(
                    in: fullRange,
                    unit: unit,
                    scheme: scheme,
                    options: options
                ) { tag, tokenRange in
                    guard let raw = tag?.rawValue else { return true }

                    let token = String(text[tokenRange])
                    let start = text.distance(from: text.startIndex, to: tokenRange.lowerBound)
                    let length = text.distance(from: tokenRange.lowerBound, to: tokenRange.upperBound)

                    let confidence: Double?
                    if scheme == .sentimentScore, let score = Double(raw) {
                        confidence = score
                    } else {
                        confidence = nil
                    }

                    let tagObj = Tag(
                        token: token,
                        label: raw,
                        scheme: scheme.rawValue,
                        confidence: confidence,
                        start: start,
                        length: length
                    )
                    tagsForText.append(tagObj)
                    return true
                }
            }

            allTags.append(tagsForText)
        }

        return MLResponse(outputs: ["tags": allTags], info: nil)
    }
}
