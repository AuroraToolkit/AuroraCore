//
//  URLFetchSkillTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 3/26/25.
//

import XCTest
@testable import AuroraAgent
@testable import AuroraCore
@testable import AuroraTaskLibrary

final class URLFetchSkillTests: XCTestCase {

    func testURLFetchSkillSuccess() async throws {
        // Create a temporary file with known content.
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent("testfile.txt")
        let expectedContent = "Hello, world!"
        try expectedContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        // Create a URLFetchSkill instance with the file URL.
        let skill = URLFetchSkill(url: fileURL.absoluteString)
        
        // Execute the skill (query and memory are not used in this simple skill).
        let result = try await skill.execute()
        
        // Assert that the returned content matches what we wrote.
        XCTAssertEqual(result, expectedContent, "The fetched content should match the expected content.")
    }

    func testURLFetchSkillInvalidURL() async {
        // Create a URLFetchSkill instance with an invalid URL.
        let skill = URLFetchSkill(url: "not-a-valid-url")
        
        do {
            _ = try await skill.execute(query: "dummy query", memory: nil)
            XCTFail("Expected an error to be thrown for an invalid URL.")
        } catch {
            // Expected: an error is thrown. We could further inspect error details if needed.
            XCTAssertNotNil(error, "An error should be thrown for an invalid URL.")
        }
    }
}
