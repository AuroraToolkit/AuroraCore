//
//  LanguageIdentificationWithTaggingTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/8/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraML
@testable import AuroraTaskLibrary

final class LanguageIdentificationWithTaggingTaskTests: XCTestCase {

    func testLanguageIdentification_English() async throws {
        // Given
        let text = "This is an English sentence."
        let service = TaggingService(
            name: "LangTagger",
            schemes: [.language],
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
              let lang = tags.first?.label.lowercased() else {
            XCTFail("Missing or invalid language tag")
            return
        }
        XCTAssertEqual(lang, "en", "Expected 'en' for English text")
    }

    func testLanguageIdentification_Spanish() async throws {
        // Given
        let text = "Esta es una frase en español."
        let service = TaggingService(
            name: "LangTagger",
            schemes: [.language],
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
              let lang = tags.first?.label.lowercased() else {
            XCTFail("Missing or invalid language tag")
            return
        }
        XCTAssertEqual(lang, "es", "Expected 'es' for Spanish text")
    }

    func testLanguageIdentification_French() async throws {
        // Given
        let text = "Ceci est une phrase française."
        let service = TaggingService(
            name: "LangTagger",
            schemes: [.language],
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
              let lang = tags.first?.label.lowercased() else {
            XCTFail("Missing or invalid language tag")
            return
        }
        XCTAssertEqual(lang, "fr", "Expected 'fr' for French text")
    }

    func testLanguageIdentification_ChineseSimplified() async throws {
        // Given
        let text = "这是一个中文句子。"
        let service = TaggingService(
            name: "LangTagger",
            schemes: [.language],
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
              let lang = tags.first?.label else {
            XCTFail("Missing or invalid language tag")
            return
        }
        // NLTagger may return "zh-Hans" or simply "zh"
        XCTAssertTrue(lang.lowercased().hasPrefix("zh"), "Expected 'zh' prefix for Chinese text, got: \(lang)")
    }

    func testLanguageIdentification_German() async throws {
        // Given
        let text = "Dies ist ein deutscher Satz."
        let service = TaggingService(
            name: "LangTagger",
            schemes: [.language],
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
              let lang = tags.first?.label.lowercased() else {
            XCTFail("Missing or invalid language tag")
            return
        }
        XCTAssertEqual(lang, "de", "Expected 'de' for German text")
    }

    func testLanguageIdentification_Italian() async throws {
        // Given
        let text = "Questa è una frase in italiano."
        let service = TaggingService(
            name: "LangTagger",
            schemes: [.language],
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
              let lang = tags.first?.label.lowercased() else {
            XCTFail("Missing or invalid language tag")
            return
        }
        XCTAssertEqual(lang, "it", "Expected 'it' for Italian text")
    }

    func testLanguageIdentification_Japanese() async throws {
        // Given
        let text = "これは日本語の文です。"
        let service = TaggingService(
            name: "LangTagger",
            schemes: [.language],
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
              let lang = tags.first?.label.lowercased() else {
            XCTFail("Missing or invalid language tag")
            return
        }
        XCTAssertEqual(lang, "ja", "Expected 'ja' for Japanese text")
    }

    func testLanguageIdentification_Arabic() async throws {
        // Given
        let text = "هذه جملة باللغة العربية."
        let service = TaggingService(
            name: "LangTagger",
            schemes: [.language],
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
              let lang = tags.first?.label.lowercased() else {
            XCTFail("Missing or invalid language tag")
            return
        }
        XCTAssertEqual(lang, "ar", "Expected 'ar' for Arabic text")
    }

    func testLanguageIdentification_Korean() async throws {
        // Given
        let text = "이것은 한국어 문장입니다."
        let service = TaggingService(
            name: "LangTagger",
            schemes: [.language],
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
              let lang = tags.first?.label.lowercased() else {
            XCTFail("Missing or invalid language tag")
            return
        }
        XCTAssertEqual(lang, "ko", "Expected 'ko' for Korean text")
    }
}
