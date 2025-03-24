//
//  Agent.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 3/19/25.
//

import Foundation

/**
    A declarative representation of an agent.

    An agent is an entity that can perform actions on behalf of a user. This can be a person, a bot, or any other entity capable of interacting with a system.
 */
struct Agent {
    /// The unique identifier for the agent.
    public let id: UUID

    /// The name of the agent.
    public let name: String

    /// A description of the agent.
    public let description: String

    /// Instructions for the agent (similar to a system prompt in an LLM) that describes the agent's personality and behavior.
    public let instructions: String

    /// The memory of the agent, storing information about past interactions and context.
    public let memory: AgentMemory

    /// The queue used for processing queries.
    private let queue: Agent.Queue

    /**
     Initializes a new `Agent` with the specified name.

     - Parameters:
        - name: The name of the workflow.
        - description: An optional description of the agent.
        - instructions: Optional instructions for the agent.
        - memory: Optional initial memory for the agent.
     */
    public init(
        name: String,
        description: String = "",
        instructions: String = "",
        memory: AgentMemory = AgentMemory()
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.instructions = instructions
        self.memory = memory
        self.queue = Agent.Queue()
    }

    public func query(_ query: String) async -> String {
        let response = await queue.enqueue(query: query) { query in
            // Simulate processing delay (for demonstration)
            try? await Task.sleep(nanoseconds: 200_000_000) // 200 ms delay
            let response = "Response for query: \(query)"
            // Save the query/response in memory.
            await self.memory.addEntry(query: query, response: response)
            return response
        }
        return response
    }

    private actor Queue {
        func enqueue(query: String, processor: (String) async -> String) async -> String {
            // Serial execution is guaranteed by actor isolation.
            return await processor(query)
        }
    }
}
