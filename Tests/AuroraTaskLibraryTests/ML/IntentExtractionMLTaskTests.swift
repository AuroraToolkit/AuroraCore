//
//  IntentExtractionMLTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/14/25.
//

import XCTest
import NaturalLanguage
@testable import AuroraCore
@testable import AuroraTaskLibrary

final class IntentExtractionMLTaskTests: XCTestCase {

    // Helper to load our trivial NLModel
    private func makeTrivialModel() throws -> NLModel {
        // this file path is the path of this source file
        let testsDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("models")
        let modelURL = testsDir
            .appendingPathComponent("TrivialTextClassifier.mlmodelc")
        return try NLModel(contentsOf: modelURL)
    }

    func testIntentExtractionSuccess() async throws {
        // Given
        let texts = ["foo", "bar"]
        let nlModel = try makeTrivialModel()
        let maxResults = 2

        let task = IntentExtractionMLTask(
            model: nlModel,
            slotSchemes: [],
            maxResults: maxResults,
            strings: texts
        )

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        guard let extracted = outputs["intents"] as? [[String: Any]] else {
            XCTFail("Output 'intents' not found or invalid.")
            return
        }
        XCTAssertFalse(extracted.isEmpty, "Should produce at least one intent")
        XCTAssertLessThanOrEqual(extracted.count, maxResults * texts.count,
                                 "Should not exceed maxResults per input")

        for intent in extracted {
            XCTAssertNotNil(intent["name"] as? String)
            XCTAssertNotNil(intent["confidence"] as? Double)
            XCTAssertNotNil(intent["parameters"] as? [String: Any])
        }
    }

    func testIntentExtractionEmptyInput() async {
        // Given
        let nlModel = try! makeTrivialModel()
        let task = IntentExtractionMLTask(model: nlModel, slotSchemes: [], strings: [])

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }

        // Then
        await XCTAssertThrowsErrorAsync(try await wrapped.execute()) { error in
            let ns = error as NSError
            XCTAssertEqual(ns.domain, "IntentExtractionMLTask")
            XCTAssertEqual(ns.code, 1)
        }
    }

    func testIntentExtractionInputOverride() async throws {
        // Given
        let nlModel = try makeTrivialModel()
        let initial = ["foo"]
        let override = ["bar"]

        let task = IntentExtractionMLTask(
            model: nlModel,
            slotSchemes: [],
            strings: initial
        )

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute(inputs: ["strings": override])

        // Then
        guard let extracted = outputs["intents"] as? [[String: Any]] else {
            XCTFail("Output 'intents' not found or invalid.")
            return
        }
        XCTAssertGreaterThanOrEqual(extracted.count, 1)
        XCTAssertTrue(["foo", "bar"].contains(extracted.first?["name"] as? String))
    }
}

// Helper for async error assertions
func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ validate: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {
        validate(error)
    }
}
