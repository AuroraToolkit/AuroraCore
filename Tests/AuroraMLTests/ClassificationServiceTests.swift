//
//  ClassificationServiceTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/17/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraML
import NaturalLanguage

final class ClassificationServiceTests: XCTestCase {

    func testClassificationWithTrivialModel() async throws {
        // Given
        let url = modelPath(for: "TrivialTextClassifier.mlmodelc")
        guard let model = try? NLModel(contentsOf: url) else {
            XCTFail("Failed to load model from \(url)")
            return
        }
        let service = ClassificationService(
            name: "trivial",
            model: model,
            scheme: "test",
            maxResults: 1
        )

        // foo → foo
        let respFoo = try await service.run(
            request: MLRequest(inputs: ["strings": ["foo"]])
        )
        let tagsFoo = respFoo.outputs["tags"] as? [Tag]
        XCTAssertEqual(tagsFoo?.first?.label, "foo")

        // bar → bar
        let respBar = try await service.run(
            request: MLRequest(inputs: ["strings": ["bar"]])
        )
        let tagsBar = respBar.outputs["tags"] as? [Tag]
        XCTAssertEqual(tagsBar?.first?.label, "bar")
    }

    func testEmptyInput() async {
        // Given
        let url = modelPath(for: "TrivialTextClassifier.mlmodelc")
        guard let model = try? NLModel(contentsOf: url) else {
            XCTFail("Failed to load model from \(url)")
            return
        }
        let service = ClassificationService(
            name: "trivial",
            model: model,
            scheme: "test"
        )

        // When / Then
        await XCTAssertThrowsErrorAsync(try await service.run(request: MLRequest(inputs: [:]))) { error in
            let ns = error as NSError
            XCTAssertEqual(ns.domain, "trivial")
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
