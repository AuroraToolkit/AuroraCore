//
//  SummarizeTextSkillTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 3/26/25.
//

import XCTest
@testable import AuroraAgent
@testable import AuroraCore
@testable import AuroraTaskLibrary
@testable import AuroraLLM

final class SummarizeTextSkillTests: XCTestCase {
    
    func testSummarizeTextSkillSuccess() async throws {
        // Given: Some sample text strings to summarize.
        let texts = [
            "Artificial intelligence is transforming the world by automating tasks and enabling new forms of collaboration.",
            "Machine learning models are at the core of modern AI systems."
        ]
        let skill = SummarizeTextSkill(strings: texts)
        
        // When: Execute the skill.
        let summary = try await skill.execute(query: "ignored", memory: nil)
        
        // Then: The summary should be non-empty.
        XCTAssertFalse(summary.isEmpty, "The summary should not be empty.")
        print("Generated summary: \(summary)")
    }
    
    func testSummarizeTextSkillWithEmptyStrings() async {
        // Given: An empty array of strings.
        let skill = SummarizeTextSkill(strings: [])
        
        // When/Then: Execution should throw an error.
        do {
            _ = try await skill.execute(query: "ignored", memory: nil)
            XCTFail("Expected an error due to empty strings, but none was thrown.")
        } catch {
            XCTAssertEqual((error as NSError).domain, "SummarizeTextSkill")
            XCTAssertEqual((error as NSError).code, 1)
        }
    }
}
