//
//  AgentMemory.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 3/20/25.
//

import Foundation

/**
    A simple memory structure for storing agent history.

    The `AgentMemory` class stores a history of agent queries and responses, allowing for the retrieval of past interactions. `AgentMemory` can be shared between multiple agents or used to store a single agent's history.
 */
public actor AgentMemory {
    /// The history of agent queries and responses.
    private var history: [AgentMemoryEntry] = []

    public init() {}

    /**
        Adds a new entry to the agent memory.

        - Parameters:
            - query: The query made by the agent.
            - response: The response given by the agent.
     */
    public func addEntry(query: String? = nil, response: String? = nil) {
        let entry = AgentMemoryEntry(query: query, response: response, timestamp: Date())
        history.append(entry)
    }

    /**
        Resets the agent memory, clearing all history.
     */
    public func clear() {
        history.removeAll()
    }

    /**
        Retrieves the history of agent queries and responses.

        - Returns: An array of `AgentMemoryEntry` objects representing the agent's history.

     */
    public func getHistory() -> [AgentMemoryEntry] {
        return history
    }

    /**
     Retrieves the history of agent queries and responses, sorted by the provided comparator.

     - Parameter sortedBy: A closure that compares two `AgentMemoryEntry` objects and returns `true` if the first element should be ordered before the second. Defaults to sorting by the `timestamp` in ascending order.
     - Returns: An array of `AgentMemoryEntry` objects sorted according to the provided closure.
     */
    public func getHistory(sortedBy sort: ((AgentMemoryEntry, AgentMemoryEntry) -> Bool) = { $0.timestamp < $1.timestamp }) -> [AgentMemoryEntry] {
        return history.sorted(by: sort)
    }
}

/**
    A single entry in the agent memory.
*/
public struct AgentMemoryEntry {
    /// The query made by the agent.
    public let query: String?

    /// The response given by the agent.
    public let response: String?

    /// The timestamp of the entry.
    public let timestamp: Date
}
