//
//  AgentTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 3/19/25.
//

import XCTest
@testable import AuroraAgent

final class AgentTests: XCTestCase {
    let agent = Agent(
        name: "TestAgent",
        description: "Test agent for unit tests",
        instructions: "You are a test agent."
    )

    func testAgentInitialization() {
        XCTAssertNotNil(agent.id, "Agent id should be set")
        XCTAssertEqual(agent.name, "TestAgent", "Agent name should be set")
        XCTAssertEqual(agent.description, "Test agent for unit tests", "Agent description should be set")
        XCTAssertEqual(agent.instructions, "You are a test agent.", "Agent instructions should be set")
    }

    func testAgentHasMemory() {
        XCTAssertNotNil(agent.memory, "Agent should have memory")
    }

    func testAgentQueryAndMemory() async throws {
        let agent = Agent(name: "MemoryAgent", description: "Agent with memory")
        let queryText = "What is the weather like?"

        // Process a query
        let response = await agent.query(queryText)
        XCTAssertTrue(response.contains(queryText), "Response should mention the query text.")

        // Retrieve memory entries
        let entries = await agent.memory.getHistory()
        XCTAssertEqual(entries.count, 1, "There should be one memory entry.")
        XCTAssertEqual(entries.first?.query, queryText, "Memory entry should record the query.")
        XCTAssertEqual(entries.first?.response, response, "Memory entry should record the correct response.")
    }

    func testSerialProcessing() async throws {
        let agent = Agent(name: "SerialAgent")
        let queries = ["Query 1", "Query 2", "Query 3"]

        // Launch queries concurrently.
        async let response1 = agent.query(queries[0])
        async let response2 = agent.query(queries[1])
        async let response3 = agent.query(queries[2])

        let responses = await [response1, response2, response3]
        XCTAssertEqual(responses.count, 3, "Should have three responses.")

        // Verify that memory contains all entries (processed serially)
        let entries = await agent.memory.getHistory()
        XCTAssertEqual(entries.count, 3, "Memory should record three queries.")
    }
}
