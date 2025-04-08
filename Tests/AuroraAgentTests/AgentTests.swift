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
        description: "Test agent for unit tests"
    ) {
        Agent.Instructions("You are a test agent.")
    }

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
        let agent = Agent(name: "MemoryAgent", description: "Agent with memory") {}
        let queryText = "What is the weather like?"

        // Process a query
        let response = await agent.query(queryText)
        XCTAssertTrue(response.contains(queryText), "Response should mention the query text.")

        // Retrieve memory entries
        let entries = await agent.memory.getHistory()
        let queries = entries.compactMap { event -> String? in
            if case let .queryReceived(query) = event.eventType {
                return query
            }
            return nil
        }
        let responses = await agent.memory.getAllResponses().map({ $0.value })

        XCTAssertEqual(entries.count, 1, "There should be one memory entry.")
        XCTAssertEqual(queries.first, queryText, "Memory entry should record the query.")
        XCTAssertEqual(responses.first, response, "Memory entry should record the correct response.")
    }

    func testSerialProcessing() async throws {
        let agent = Agent(name: "SerialAgent", description: "Serial agent") {}
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

    func testPersonalityLLMPrompt() {
        // Create a Personality component.
        let personality = Agent.Personality(
            name: "FriendlyBot",
            description: "An assistant that is warm and friendly.",
            tone: .friendly,
            traits: ["helpful", "cheerful"],
            languageStyle: "concise"
        )

        // Convert to an LLM prompt.
        let prompt = personality.toLLMPrompt()

        // Check that the prompt contains all the necessary details.
        XCTAssertTrue(prompt.contains("FriendlyBot"), "Prompt should contain the personality name.")
        XCTAssertTrue(prompt.contains("warm and friendly"), "Prompt should include the description.")
        XCTAssertTrue(prompt.contains("friendly"), "Prompt should reflect the tone.")
        XCTAssertTrue(prompt.contains("helpful, cheerful"), "Prompt should list the traits.")
        XCTAssertTrue(prompt.contains("concise"), "Prompt should include the language style.")
    }

    func testAgentContextMerging() {
        let agent = Agent(name: "ContextAgent", description: "Agent with multiple context components") {
            // First Context component
            Agent.Context(data: ["key1": "value1", "key2": "value2"])
            // Second Context component that overwrites key2 and adds key3.
            Agent.Context(data: ["key2": "overwritten", "key3": 3])
        }

        let context = agent.context
        XCTAssertEqual(context["key1"] as? String, "value1", "Context should contain key1 with value 'value1'")
        XCTAssertEqual(context["key2"] as? String, "overwritten", "Context should have key2 overwritten with 'overwritten'")
        XCTAssertEqual(context["key3"] as? Int, 3, "Context should contain key3 with value 3")
    }

    func testAgentLifecycle() {
        // Flags for tracking lifecycle hook execution.
        var didInit = false
        var didTeardown = false

        // Define a lifecycle component with onInit and onTeardown hooks.
        let lifecycle = Agent.Lifecycle(
            onInit: { didInit = true },
            onTeardown: { didTeardown = true }
        )

        let agent = Agent(name: "LifecycleAgent", description: "Agent with lifecycle") {
            Agent.Instructions("Test instructions")
            // Add the lifecycle component.
            Agent.Component.lifecycle(lifecycle)
        }

        // onInit should have executed during initialization.
        XCTAssertTrue(didInit, "Lifecycle onInit should have been executed during agent initialization.")

        // Call shutdown to trigger onTeardown.
        agent.shutdown()
        XCTAssertTrue(didTeardown, "Lifecycle onTeardown should have been executed upon shutdown.")
    }
}
