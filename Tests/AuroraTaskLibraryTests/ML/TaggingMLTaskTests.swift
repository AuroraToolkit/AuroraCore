//
//  TaggingMLTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/6/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraML
@testable import AuroraTaskLibrary
import NaturalLanguage

final class TaggingMLTaskTests: XCTestCase {

    func testTaggingTaskSuccess() async throws {
        // Given
        let text1 = "Hello"
        let text2 = "World"
        let tag1 = Tag(
            token: text1,
            label: "GREETING",
            scheme: "mock",
            confidence: nil,
            start: 0,
            length: text1.count
        )
        let tag2 = Tag(
            token: text2,
            label: "OBJECT",
            scheme: "mock",
            confidence: nil,
            start: 0,
            length: text2.count
        )
        let tags: [[Tag]] = [[tag1], [tag2]]
        let service = MockMLService(
            name: "MockTaggerService",
            response: MLResponse(outputs: ["tags": tags], info: nil)
        )
        let task = TaggingMLTask(service: service, strings: ["\(text1) \(text2)"])

        // When
        guard case let .task(unwrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await unwrapped.execute()

        // Then
        guard let resultTags = outputs["tags"] as? [[Tag]] else {
            XCTFail("Output 'tags' missing or of wrong type")
            return
        }
        XCTAssertEqual(resultTags.count, 2)
        XCTAssertEqual(resultTags[0], [tag1])
        XCTAssertEqual(resultTags[1], [tag2])
    }

    func testTaggingTaskEmptyInput() async {
        // Given
        let service = MockMLService(
            name: "MockTaggerService",
            response: MLResponse(outputs: ["tags": [[Tag]]()], info: nil)
        )
        let task = TaggingMLTask(service: service)

        // When
        guard case let .task(unwrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }

        // Then
        do {
          _ = try await unwrapped.execute()
          XCTFail("Expected error for empty input")
        } catch {
          let ns = error as NSError
          XCTAssertEqual(ns.domain, "TaggingMLTask")
          XCTAssertEqual(ns.code, 1)
        }
    }

    func testTaggingTaskInputOverride() async throws {
        // Given
        let initial = ["A"]
        let override = ["X", "Y"]
        let x = "X"
        let y = "Y"
        let tagX = Tag(
            token: x,
            label: "T1",
            scheme: "mock",
            confidence: nil,
            start: 0,
            length: x.count
        )
        let tagY = Tag(
            token: y,
            label: "T2",
            scheme: "mock",
            confidence: nil,
            start: 0,
            length: y.count
        )
        let tags: [[Tag]] = [[tagX], [tagY]]
        let service = MockMLService(
            name: "MockTaggerService",
            response: MLResponse(outputs: ["tags": tags], info: nil)
        )
        let task = TaggingMLTask(service: service, strings: initial)

        // When
        guard case let .task(unwrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await unwrapped.execute(inputs: ["strings": override])

        // Then
        guard let resultTags = outputs["tags"] as? [[Tag]] else {
            XCTFail("Output 'tags' missing or of wrong type")
            return
        }
        XCTAssertEqual(resultTags[0], [tagX])
        XCTAssertEqual(resultTags[1], [tagY])
    }

    func testTaggingTaskEntityExtraction() async throws {
        // Given
        let service = TaggingService(
            name: "EntityTagger",
            schemes: [.nameType],
            unit: .word,
            options: [.omitWhitespace, .omitPunctuation]
        )
        let input = "Alice went to Paris"
        let task = TaggingMLTask(service: service, strings: [input])

        // When
        guard case let .task(unwrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await unwrapped.execute()

        // Then
        guard let tagArrays = outputs["tags"] as? [[Tag]] else {
            XCTFail("Output 'tags' missing or wrong type")
            return
        }
        let allTags = tagArrays[0]  // ["Alice","went","to","Paris"] tags

        // Filter to only the entity labels you care about:
        let entityTags = allTags.filter {
          $0.scheme == NLTagScheme.nameType.rawValue &&
          ($0.label == NLTag.personalName.rawValue
           || $0.label == NLTag.placeName.rawValue
           || $0.label == NLTag.organizationName.rawValue)
        }

        XCTAssertEqual(entityTags.count, 2, "Expected two entity tags")

        // Validate “Alice” tag
        let aliceTag = entityTags.first { $0.token == "Alice" }
        XCTAssertNotNil(aliceTag)
        XCTAssertEqual(aliceTag!.label, "PersonalName")
        XCTAssertEqual(aliceTag!.scheme, NLTagScheme.nameType.rawValue)
        XCTAssertNil(aliceTag!.confidence)
        XCTAssertEqual(aliceTag!.start, 0)
        XCTAssertEqual(aliceTag!.length, 5)

        // Validate “Paris” tag
        let parisTag = entityTags.first { $0.token == "Paris" }
        XCTAssertNotNil(parisTag)
        XCTAssertEqual(parisTag!.label, "PlaceName")
        XCTAssertEqual(parisTag!.scheme, NLTagScheme.nameType.rawValue)
        XCTAssertNil(parisTag!.confidence)
        XCTAssertEqual(parisTag!.start, 14)
        XCTAssertEqual(parisTag!.length, 5)
    }

    func testTaggingTaskServiceErrorPropagates() async {
        // Given a service that always throws
        let service = MockMLService(
            name: "MockError",
            response: MLResponse(outputs: ["tags": [[Tag]]()], info: nil),
            shouldThrow: true
        )
        let task = TaggingMLTask(service: service, strings: ["Anything"])

        // When
        guard case let .task(unwrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }

        // Then
        do {
            _ = try await unwrapped.execute()
            XCTFail("Expected service error to propagate")
        } catch {
            let ns = error as NSError
            XCTAssertEqual(ns.domain, "MockMLService")
            XCTAssertEqual(ns.code, 99)
        }
    }

    func testTaggingTaskMissingTagsKey() async {
        // Given a service that returns a different key
        let service = MockMLService(
            name: "MockMissing",
            response: MLResponse(outputs: ["foo": "bar"], info: nil)
        )
        let task = TaggingMLTask(service: service, strings: ["Hello"])

        // When
        guard case let .task(unwrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }

        // Then
        do {
            _ = try await unwrapped.execute()
            XCTFail("Expected missing‐tags error")
        } catch {
            let ns = error as NSError
            XCTAssertEqual(ns.domain, "TaggingMLTask")
            XCTAssertEqual(ns.code, 2)
        }
    }

    func testTaggingTaskSentimentSchemeMultipleInputs() async throws {
        // Given
        let positive = "I love this!"
        let negative = "I hate this!"
        let service = TaggingService(
            name: "SentimentTagger",
            schemes: [.sentimentScore],
            unit: .paragraph
        )
        let task = TaggingMLTask(service: service, strings: [positive, negative])

        // When
        guard case let .task(unwrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await unwrapped.execute()

        // Then
        guard let tagArrays = outputs["tags"] as? [[Tag]] else {
            XCTFail("Output 'tags' missing or wrong type")
            return
        }
        XCTAssertEqual(tagArrays.count, 2, "Expected one tag-list per input string")

        // Positive input should yield a positive score
        let positiveTag = tagArrays[0].first
        XCTAssertEqual(positiveTag?.token, positive)
        XCTAssertEqual(positiveTag?.scheme, NLTagScheme.sentimentScore.rawValue)
        XCTAssertNotNil(positiveTag?.confidence)
        XCTAssertTrue((positiveTag!.confidence ?? 0) > 0,
                      "Expected positive sentiment for “\(positive)”")

        // Negative input should yield a negative score
        let negativeTag = tagArrays[1].first
        XCTAssertEqual(negativeTag?.token, negative)
        XCTAssertEqual(negativeTag?.scheme, NLTagScheme.sentimentScore.rawValue)
        XCTAssertNotNil(negativeTag?.confidence)
        XCTAssertTrue((negativeTag!.confidence ?? 0) < 0,
                      "Expected negative sentiment for “\(negative)”")
    }

    func testTaggingTaskPreservesInputOrder() async throws {
        // Given
        let inputs = ["First sentence.", "Second sentence."]
        let service = TaggingService(
            name: "LemmaTagger",
            schemes: [.lemma],
            unit: .word
        )
        let task = TaggingMLTask(service: service, strings: inputs)

        // When
        guard case let .task(unwrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await unwrapped.execute()
        let arrays = outputs["tags"] as! [[Tag]]

        // Then
        XCTAssertEqual(arrays.count, inputs.count)

        // Expect exactly the two tokens, in order, for each input:
        let firstTokens  = arrays[0].map(\.token)
        let secondTokens = arrays[1].map(\.token)

        XCTAssertEqual(firstTokens, ["First", "sentence"])
        XCTAssertEqual(secondTokens, ["Second", "sentence"])
    }
}
