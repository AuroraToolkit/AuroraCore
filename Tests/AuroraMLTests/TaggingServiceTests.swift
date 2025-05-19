//
//  TaggingServiceTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/17/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraML
import NaturalLanguage

final class TaggingServiceTests: XCTestCase {

  func testLexicalClassTagging() async throws {
    // Given
    let service = TaggingService(schemes: [.lexicalClass])
    let texts = ["The quick brown fox"]

    // When
    let resp = try await service.run(
      request: MLRequest(inputs: ["strings": texts])
    )
    let groups = resp.outputs["tags"] as? [[Tag]]
    let tags = groups?.first

    // Then
    XCTAssertNotNil(tags)
    XCTAssertTrue(
      tags!.contains { $0.token.lowercased() == "fox" && $0.label == "Noun" },
      "Expected 'fox' tagged as Noun"
    )
  }

  func testEmptyInput() async {
    // Given
    let service = TaggingService(schemes: [.lexicalClass])

    // When / Then
    await XCTAssertThrowsErrorAsync(try await service.run(request: MLRequest(inputs: [:]))) { error in
      let ns = error as NSError
      XCTAssertEqual(ns.domain, "TaggingService")
      XCTAssertEqual(ns.code, 1)
    }
  }
}
