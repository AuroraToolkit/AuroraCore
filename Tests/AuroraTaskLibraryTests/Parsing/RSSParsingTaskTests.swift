//
//  RSSParsingTaskTests.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/10/24.
//

import XCTest
@testable import AuroraCore
@testable import AuroraTaskLibrary

final class RSSParsingTaskTests: XCTestCase {

    func testRSSParsingTaskValidFeed() async throws {
        // Given
        let validRSSData = """
        <rss version="2.0">
            <channel>
                <item>
                    <title>Test Article 1</title>
                    <link>https://example.com/article1</link>
                    <description>Description for article 1</description>
                    <guid>12345</guid>
                </item>
                <item>
                    <title>Test Article 2</title>
                    <link>https://example.com/article2</link>
                    <description>Description for article 2</description>
                    <guid>67890</guid>
                </item>
            </channel>
        </rss>
        """.data(using: .utf8)!

        let task = RSSParsingTask(feedData: validRSSData)

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()

        // Then
        guard let articles = taskOutputs["articles"] as? [RSSArticle] else {
            XCTFail("Output 'articles' not found or invalid")
            return
        }
        XCTAssertEqual(articles.count, 2, "There should be 2 articles parsed.")
        XCTAssertEqual(articles[0].title, "Test Article 1", "First article title should match.")
        XCTAssertEqual(articles[0].link, "https://example.com/article1", "First article link should match.")
        XCTAssertEqual(articles[1].title, "Test Article 2", "Second article title should match.")
        XCTAssertEqual(articles[1].link, "https://example.com/article2", "Second article link should match.")
    }

    func testRSSParsingTaskInvalidFeed() async {
        // Given
        let invalidRSSData = "Invalid RSS Feed".data(using: .utf8)!
        let task = RSSParsingTask(feedData: invalidRSSData)

        // When/Then
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap the Workflow.Task from the component.")
                return
            }
            _ = try await unwrappedTask.execute()
            XCTFail("Expected an error to be thrown, but no error was thrown.")
        } catch {
            XCTAssertEqual((error as NSError).domain, "RSSParsingTask", "Error domain should match.")
            XCTAssertEqual((error as NSError).code, 2, "Error code should match.")
        }
    }

    func testRSSParsingTaskMissingFeedData() async {
        // Given
        let task = RSSParsingTask(feedData: Data())

        // When/Then
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap the Workflow.Task from the component.")
                return
            }
            _ = try await unwrappedTask.execute()
            XCTFail("Expected an error to be thrown, but no error was thrown.")
        } catch {
            XCTAssertEqual((error as NSError).domain, "RSSParsingTask", "Error domain should match.")
            XCTAssertEqual((error as NSError).code, 1, "Error code should match for missing feed data.")
        }
    }

    func testRSSParsingTaskEmptyFeed() async throws {
        // Given
        let emptyRSSData = """
        <rss version="2.0">
            <channel></channel>
        </rss>
        """.data(using: .utf8)!

        let task = RSSParsingTask(feedData: emptyRSSData)

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()

        // Then
        guard let articles = taskOutputs["articles"] as? [RSSArticle] else {
            XCTFail("Output 'articles' not found or invalid")
            return
        }
        XCTAssertTrue(articles.isEmpty, "Articles array should be empty for an RSS feed with no items.")
    }

    func testRSSParsingTaskMalformedFeed() async {
        // Given
        let malformedRSSData = """
        <rss version="2.0">
            <channel>
                <item>
                    <title>Missing closing tag for item
                </item>
            </channel>
        """.data(using: .utf8)!
        let task = RSSParsingTask(feedData: malformedRSSData)

        // When/Then
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap the Workflow.Task from the component.")
                return
            }
            _ = try await unwrappedTask.execute()
            XCTFail("Expected an error to be thrown, but no error was thrown.")
        } catch {
            XCTAssertEqual((error as NSError).domain, "RSSParsingTask", "Error domain should match.")
            XCTAssertEqual((error as NSError).code, 2, "Error code should match for malformed RSS feed.")
        }
    }

    func testRSSParsingTaskLargeFeed() async throws {
        // Given
        let largeRSSData = """
        <rss version="2.0">
            <channel>
                \(String(repeating: """
                <item>
                    <title>Article Title</title>
                    <link>https://example.com/article</link>
                    <description>Article description</description>
                    <guid>12345</guid>
                </item>
                """, count: 1000))
            </channel>
        </rss>
        """.data(using: .utf8)!

        let task = RSSParsingTask(feedData: largeRSSData)

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()

        // Then
        guard let articles = taskOutputs["articles"] as? [RSSArticle] else {
            XCTFail("Output 'articles' not found or invalid")
            return
        }
        XCTAssertEqual(articles.count, 1000, "There should be 1000 articles parsed.")
    }

    func testRSSParsingTaskPartiallyValidFeedMissingLink() async throws {
        // Given
        let partiallyValidRSSData = """
        <rss version="2.0">
            <channel>
                <item>
                    <title>Valid Article</title>
                    <link>https://example.com/valid</link>
                    <description>Description</description>
                    <guid>12345</guid>
                </item>
                <item>
                    <title>Malformed Article</title>
                </item>
            </channel>
        </rss>
        """.data(using: .utf8)!
        let task = RSSParsingTask(feedData: partiallyValidRSSData)

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()

        // Then
        guard let articles = taskOutputs["articles"] as? [RSSArticle] else {
            XCTFail("Output 'articles' not found or invalid")
            return
        }
        XCTAssertEqual(articles.count, 1, "Only valid articles should be parsed.")
        XCTAssertEqual(articles[0].title, "Valid Article", "The valid article should be parsed correctly.")
    }

    func testRSSParsingTaskPartiallyValidFeedMissingTitle() async throws {
        // Given
        let partiallyValidRSSData = """
        <rss version="2.0">
            <channel>
                <item>
                    <title>Valid Article</title>
                    <link>https://example.com/valid</link>
                    <description>Description</description>
                    <guid>12345</guid>
                </item>
                <item>
                    <link>https://example.com/valid</link>
                </item>
            </channel>
        </rss>
        """.data(using: .utf8)!
        let task = RSSParsingTask(feedData: partiallyValidRSSData)

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()

        // Then
        guard let articles = taskOutputs["articles"] as? [RSSArticle] else {
            XCTFail("Output 'articles' not found or invalid")
            return
        }
        XCTAssertEqual(articles.count, 1, "Only valid articles should be parsed.")
        XCTAssertEqual(articles[0].title, "Valid Article", "The valid article should be parsed correctly.")
    }

    func testRSSParsingTaskFullyInvalidFeed() async throws {
        // Given
        let invalidRSSData = """
        <rss version="2.0">
            <channel>
                <item>
                    <description>No title or link</description>
                    <guid>12345</guid>
                </item>
            </channel>
        </rss>
        """.data(using: .utf8)!
        let task = RSSParsingTask(feedData: invalidRSSData)

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()

        // Then
        guard let articles = taskOutputs["articles"] as? [RSSArticle] else {
            XCTFail("Output 'articles' not found or invalid")
            return
        }
        XCTAssertEqual(articles.count, 0, "No articles should be parsed if all are invalid.")
    }
}
