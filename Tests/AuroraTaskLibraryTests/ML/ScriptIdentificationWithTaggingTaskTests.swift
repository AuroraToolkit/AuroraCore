//
//  ScriptIdentificationWithTaggingTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/8/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraML
@testable import AuroraTaskLibrary

final class ScriptIdentificationWithTaggingTaskTests: XCTestCase {

    // Extract the ISO 15924 script identifiers for various languages (Latin ['Latn'], Han ['Han'], Cyrillic ['Cyrl'], Arabic ['Arab'], etc.)

    func testScriptIdentification_Latin() async throws {
        // Given
        let text = "Hello, world!"
        let service = TaggingService(
            name: "ScriptTagger",
            schemes: [.script],
            unit: .paragraph
        )
        let task = TaggingMLTask(service: service, strings: [text])

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        guard let result = outputs["tags"] as? [[Tag]],
              let tags = result.first,
              let script = tags.first?.label else {
            XCTFail("Missing or invalid script tag")
            return
        }
        XCTAssertEqual(script, "Latn", "Expected 'Latn' for ASCII text")
    }

    func testScriptIdentification_Han() async throws {
        // Given
        let text = "这是中文文本。"
        let service = TaggingService(
            name: "ScriptTagger",
            schemes: [.script],
            unit: .paragraph
        )
        let task = TaggingMLTask(service: service, strings: [text])

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        guard let result = outputs["tags"] as? [[Tag]],
              let tags = result.first,
              let script = tags.first?.label else {
            XCTFail("Missing or invalid script tag")
            return
        }
        XCTAssertTrue(script.contains("Han"), "Expected a 'Han' script tag for Chinese text, got: \(script)")
    }

    func testScriptIdentification_Cyrillic() async throws {
        // Given
        let text = "Привет мир"
        let service = TaggingService(
            name: "ScriptTagger",
            schemes: [.script],
            unit: .paragraph
        )
        let task = TaggingMLTask(service: service, strings: [text])

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        guard let result = outputs["tags"] as? [[Tag]],
              let tags = result.first,
              let script = tags.first?.label else {
            XCTFail("Missing or invalid script tag")
            return
        }
        XCTAssertEqual(script, "Cyrl", "Expected 'Cyrl' for Russian text")
    }

    func testScriptIdentification_Arabic() async throws {
        // Given
        let text = "مرحبا بالعالم"
        let service = TaggingService(
            name: "ScriptTagger",
            schemes: [.script],
            unit: .paragraph
        )
        let task = TaggingMLTask(service: service, strings: [text])

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        guard let result = outputs["tags"] as? [[Tag]],
              let tags = result.first,
              let script = tags.first?.label else {
            XCTFail("Missing or invalid script tag")
            return
        }
        XCTAssertEqual(script, "Arab", "Expected 'Arab' for Arabic text")
    }
}
