//
//  IntentExtractionServiceTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/17/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraML
import NaturalLanguage

final class IntentExtractionServiceTests: XCTestCase {

    func testIntentExtractionWithTrivialModel() async throws {
        // Given: a trivial text‐classifier that labels "foo" → foo, "bar" → bar
        let url = modelPath(for: "TrivialTextClassifier.mlmodelc")
        guard let model = try? NLModel(contentsOf: url) else {
            XCTFail("Failed to load model from \(url)")
            return
        }
        let service = IntentExtractionService(model: model, maxResults: 1)

        // When
        let texts = ["foo", "bar"]
        let resp = try await service.run(
            request: MLRequest(inputs: ["strings": texts])
        )
        let intents = resp.outputs["intents"] as? [[String: Any]]

        // Then
        XCTAssertEqual(intents?.count, texts.count)
        XCTAssertEqual(intents?[0]["name"] as? String, "foo")
        XCTAssertGreaterThan(intents?[0]["confidence"] as? Double ?? 0, 0)
    }

    func testIntentExtractionMissingInput() async {
        // Given
        let url = modelPath(for: "TrivialTextClassifier.mlmodelc")
        guard let model = try? NLModel(contentsOf: url) else {
            XCTFail("Failed to load model from \(url)")
            return
        }
        let service = IntentExtractionService(model: model, maxResults: 1)

        // When / Then
        await XCTAssertThrowsErrorAsync(try await service.run(request: MLRequest(inputs: [:]))) { error in
            let ns = error as NSError
            // underlying ClassificationService will complain about missing "strings"
            XCTAssertEqual(ns.code, 1)
        }
    }

    private func modelPath(for filename: String) -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("models")
            .appendingPathComponent(filename)
    }
}
