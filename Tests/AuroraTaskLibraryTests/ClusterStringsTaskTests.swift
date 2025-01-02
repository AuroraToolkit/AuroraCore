//
//  ClusterStringsTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/1/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraLLM
@testable import AuroraTaskLibrary

final class ClusterStringsTaskTests: XCTestCase {

    func testClusterStringsTaskSuccess() async throws {
        // Given
        let stringsToCluster = ["Apple is a tech company.", "The sun is a star.", "Oranges are fruits."]
        let expectedClusters = [
            "Cluster 1": ["Apple is a tech company."],
            "Cluster 2": ["The sun is a star."],
            "Cluster 3": ["Oranges are fruits."]
        ]
        let mockResponseText = """
        {
          "Cluster 1": ["Apple is a tech company."],
          "Cluster 2": ["The sun is a star."],
          "Cluster 3": ["Oranges are fruits."]
        }
        """
        let mockService = MockLLMService(
            name: "MockService",
            expectedResult: .success(MockLLMResponse(text: mockResponseText))
        )

        let task = ClusterStringsTask(
            llmService: mockService,
            strings: stringsToCluster,
            maxClusters: 3
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await unwrappedTask.execute()

        // Then
        guard let clusters = outputs["clusters"] as? [String: [String]] else {
            XCTFail("Output 'clusters' not found or invalid.")
            return
        }
        XCTAssertEqual(clusters, expectedClusters, "The clusters should match the expected output.")
    }

    func testClusterStringsTaskEmptyInput() async {
        // Given
        let mockService = MockLLMService(
            name: "MockService",
            expectedResult: .success(MockLLMResponse(text: "{}"))
        )
        let task = ClusterStringsTask(
            llmService: mockService,
            strings: [],
            maxClusters: 3
        )

        // When/Then
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap Workflow.Task.")
                return
            }
            _ = try await unwrappedTask.execute()
            XCTFail("Expected an error to be thrown for empty input, but no error was thrown.")
        } catch {
            XCTAssertEqual((error as NSError).domain, "ClusterStringsTask", "Error domain should match.")
            XCTAssertEqual((error as NSError).code, 1, "Error code should match for empty input.")
        }
    }

    func testClusterStringsTaskIntegrationWithOllama() async throws {
        // Given
        let stringsToCluster = ["AI is transforming the world.", "The stock market dropped today."]
        let ollamaService = OllamaService(name: "OllamaTest")

        let task = ClusterStringsTask(
            llmService: ollamaService,
            strings: stringsToCluster,
            maxClusters: 2
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await unwrappedTask.execute()

        // Then
        guard let clusters = outputs["clusters"] as? [String: [String]] else {
            XCTFail("Output 'clusters' not found or invalid.")
            return
        }

        XCTAssertFalse(clusters.isEmpty, "Results should not be empty.")
        print("Integration test results: \(clusters)")
    }

    func testClusterStringsTaskExpectedClustersWithOllama() async throws {
        // Given
        let stringsToCluster = [
            "AI is transforming the world.",
            "The stock market dropped today.",
            "Machine learning drives innovation.",
            "Investors are cautious about the economy."
        ]
        let expectedClusters = [
            "Cluster 1": ["AI is transforming the world.", "Machine learning drives innovation."],
            "Cluster 2": ["The stock market dropped today.", "Investors are cautious about the economy."]
        ]

        let ollamaService = OllamaService(name: "OllamaTest")

        let task = ClusterStringsTask(
            llmService: ollamaService,
            strings: stringsToCluster,
            maxClusters: 2
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await unwrappedTask.execute()

        // Then
        guard let clusteredStrings = outputs["clusters"] as? [String: [String]] else {
            XCTFail("Output 'clusteredStrings' not found or invalid.")
            return
        }

        XCTAssertFalse(clusteredStrings.isEmpty, "Clustered strings should not be empty.")

        // Validate structure and content
        XCTAssertEqual(clusteredStrings.keys.count, 2, "There should be exactly 2 clusters.")

        // Ensure the keys (cluster identifiers) match
        XCTAssertEqual(
            Set(clusteredStrings.keys),
            Set(expectedClusters.keys),
            "The cluster keys do not match the expected keys."
        )

        // Flatten and sort the clusters
        let flattenedClusteredStrings = clusteredStrings.values.map { $0.sorted() }.sorted(by: { $0.first ?? "" < $1.first ?? "" })
        let flattenedExpectedClusters = expectedClusters.values.map { $0.sorted() }.sorted(by: { $0.first ?? "" < $1.first ?? "" })

        XCTAssertTrue(
            clusteredStrings.values.flatMap { $0 }.contains(where: { stringsToCluster.contains($0) }),
            "All input strings should be present in the clusters."
        )

        // Compare the flattened arrays since we can't predict the order of the clusters
        XCTAssertEqual(
            flattenedClusteredStrings,
            flattenedExpectedClusters,
            "The clustered strings do not match the expected clusters."
        )

        print("Integration test results: \(clusteredStrings)")
    }
}
