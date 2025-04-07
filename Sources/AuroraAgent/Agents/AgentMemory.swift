//
//  AgentMemory.swift
//  AuroraAgent
//
//  Created by Dan Murrell Jr on 3/20/25.
//

import Foundation

/**
 Manages the memory for an Agent in AuroraToolkit.

 This actor maintains both a chronological history of events (agent's thoughts, decisions, and actions)
 and a knowledge bank for long-term storage, as well as a separate storage for model responses.

 - Note: AgentMemory is designed to be shareable among multiple agents, allowing for collective memory
         and knowledge sharing.
 */
public actor AgentMemory {
    /// An array representing the chronological history of memory events.
    private var history: [Event] = []

    /// A dictionary storing model responses, keyed by the associated event's unique identifier.
    private var responses: [UUID: String] = [:]

    /// A dictionary representing the knowledge bank, storing key-value pairs of learned information.
    private var knowledge: [String: Any] = [:]

    /**
     Adds a new memory event to the chronological history.

     - Parameter event: The Event to add.
     */
    public func addEvent(_ event: Event) {
        history.append(event)
    }

    /**
     Retrieves the complete chronological history of memory events, optionally sorted by a provided comparator.

     - Parameter sortedBy: An optional closure that compares two Event objects and returns true if the first should be ordered before the second.
       If not provided, the events will be sorted by their timestamp in ascending order.
     - Returns: An array of Event objects representing the sorted history.
     */
    public func getHistory(sortedBy: ((Event, Event) -> Bool)? = nil) -> [Event] {
        if let comparator = sortedBy {
            return history.sorted(by: comparator)
        } else {
            return history.sorted(by: { $0.timestamp < $1.timestamp })
        }
    }

    /**
     Clears the entire chronological history of memory events.

     - Note: This will remove all stored events.
     */
    public func clearHistory() {
        history.removeAll()
    }

    /**
     Stores a model response associated with a specific event.

     - Parameters:
       - eventID: The unique identifier of the event.
       - response: The model's response to store.
     */
    public func addResponse(for eventID: UUID, response: String) {
        responses[eventID] = response
    }

    /**
     Retrieves the model response for a given event identifier.

     - Parameter eventID: The unique identifier of the event.
     - Returns: The stored response, or nil if not found.
     */
    public func getResponse(for eventID: UUID) -> String? {
        return responses[eventID]
    }

    /**
     Retrieves all stored model responses.

     - Returns: A dictionary with event IDs as keys and responses as values.
     */
    public func getAllResponses() -> [UUID: String] {
        return responses
    }

    /**
     Clears all stored model responses.

     - Note: This will remove all responses from storage.
     */
    public func clearResponses() {
        responses.removeAll()
    }

    /**
     Adds or updates a knowledge entry in the knowledge bank.

     - Parameters:
       - key: The key for the knowledge entry.
       - value: The value to store for the given key.
     */
    public func addKnowledge(key: String, value: Any) {
        knowledge[key] = value
    }

    /**
     Retrieves a knowledge entry for the specified key.

     - Parameter key: The key for which to retrieve the knowledge entry.
     - Returns: The stored value for the key, or nil if not found.
     */
    public func getKnowledge(for key: String) -> Any? {
        return knowledge[key]
    }

    /**
     Retrieves the entire knowledge bank.

     - Returns: A dictionary containing all knowledge entries.
     */
    public func getAllKnowledge() -> [String: Any] {
        return knowledge
    }

    /**
     Clears all entries in the knowledge bank.

     - Note: This will remove all stored knowledge.
     */
    public func clearKnowledge() {
        knowledge.removeAll()
    }

    // MARK: - Helpers

    /**
        Adds a query to the memory and associates a response with it.

        - Parameters:
            - query: The query string to add.
            - response: The response string to associate with the query.
     */
    public func addQuery(_ query: String, response: String) {
        let event = Event(eventType: .queryReceived(query: query))
        addEvent(event)
        addResponse(for: event.id, response: response)
    }

    // MARK: - Nested Event and EventType Definitions

    /**
     Represents an event in the agent's chronological memory.

     Each event captures a unique identifier, the timestamp, a structured event type,
     and an optional human-readable message describing the event.
     */
    public struct Event {
        /// The unique identifier for the event.
        public let id: UUID

        /// The timestamp when the event occurred.
        public let timestamp: Date

        /// The structured type of the event.
        public let eventType: EventType

        /// An optional human-readable message describing the event.
        public let message: String?

        /**
         Initializes a new Event.

         - Parameters:
            - id: The unique identifier for the event (default is a new UUID).
            - timestamp: The time when the event occurred (default is the current time).
            - eventType: The structured type of the event.
            - message: An optional description of the event (default is nil).
         */
        public init(id: UUID = UUID(), timestamp: Date = Date(), eventType: EventType, message: String? = nil) {
            self.id = id
            self.timestamp = timestamp
            self.eventType = eventType
            self.message = message
        }
    }

    /**
     Enumerates the types of events that can be recorded in AgentMemory.

     Use associated values to capture additional structured data for each event type.
     */
    public enum EventType {
        /// An event indicating that a query was received.
        case queryReceived(query: String)

        /// An event indicating that a skill was invoked.
        case skillInvocation(skillName: String, parameters: [String: Any]?)

        /// An event indicating that a skill completed its execution.
        case skillCompletion(skillName: String, status: String)

        /// An event indicating that a response was received.
        case responseReception

        /// An event indicating that an error occurred.
        case errorOccurred(error: Error)

        /// An event indicating that knowledge extraction has taken place.
        case knowledgeExtraction

        /// An event indicating that an action was performed.
        case actionPerformed(actionName: String)
    }
}
