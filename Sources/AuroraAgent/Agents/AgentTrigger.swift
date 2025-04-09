//
//  AgentTrigger.swift
//  AuroraAgent
//
//  Created by Dan Murrell Jr on 4/9/25.
//


import Foundation

/**
 Represents an extensible trigger condition that can be evaluated in a given context.

 Conforming types must implement `evaluate(context:)` to determine whether the condition is satisfied.
 */
public protocol TriggerConditionProtocol {
    /**
     Evaluates the condition based on provided context data.
     
     - Parameter context: A dictionary with contextual data (for example, a query or system state).
     - Returns: `true` if the condition is met; otherwise, `false`.
     */
    func evaluate(context: [String: Any]?) -> Bool
}

/**
 A default trigger condition that checks if a query contains a specified substring.
 */
public struct QueryContainsCondition: TriggerConditionProtocol {
    /// The substring to search for in the query.
    public let substring: String

    /**
     Initializes a new QueryContainsCondition.
     
     - Parameter substring: The substring that must be present in the query.
     */
    public init(substring: String) {
        self.substring = substring
    }
    
    public func evaluate(context: [String: Any]?) -> Bool {
        if let query = context?["query"] as? String {
            return query.contains(substring)
        }
        return false
    }
}

/**
 Represents an event emitted by a trigger.
 
 The TriggerEvent encapsulates the identifier of the triggering component,
 the type of event (using an enum with associated values for structured data), and a timestamp.
 */
public struct TriggerEvent {
    /// The unique identifier for the trigger that emitted the event.
    public let triggerID: UUID
    
    /// The type of event being emitted.
    public let eventType: TriggerEventType
    
    /// The timestamp when the event occurred.
    public let timestamp: Date
    
    /**
     Initializes a new TriggerEvent.
     
     - Parameters:
       - triggerID: The unique identifier for the trigger.
       - eventType: The type of event.
       - timestamp: The time the event occurred (default is the current time).
     */
    public init(triggerID: UUID, eventType: TriggerEventType, timestamp: Date = Date()) {
        self.triggerID = triggerID
        self.eventType = eventType
        self.timestamp = timestamp
    }
}

/**
 Enumerates the types of events that can be emitted by a trigger.
 
 By using associated values, each event type can carry structured data. The `custom` case allows
 arbitrary key-value parameters for events that do not fit into the predefined cases.
 */
public enum TriggerEventType {
    // MARK: - Interaction Events
    /// Fired when a query is received.
    case queryReceived(query: String)
    /// Fired when the user interacts with the system (e.g., a button press or voice command).
    case userInteraction(action: String, details: [String: Any]?)
    /// Fired when a specific notification is received.
    case notificationReceived(name: String)

    // MARK: - File System Events
    /// Fired when a file is modified.
    case fileChanged(file: URL)
    /// Fired when the contents of a directory change.
    case directoryChanged(directory: URL)

    // MARK: - Time-Based Events
    /// Fired when a scheduled alarm goes off at a specific date and time.
    case alarmTriggered(at: Date)
    /// Fired after a specific time interval has elapsed.
    case timeElapsed(interval: TimeInterval)

    // MARK: - Sensor and External Data Events
    /// Fired when a sensor reports a reading.
    case sensorReading(sensorType: String, value: Double, unit: String?)
    /// Fired when a weather update occurs, including condition, temperature, and location.
    case weatherUpdate(condition: String, temperature: Double, location: String)
    /// Fired when the network connectivity status changes.
    case networkStatusChanged(connected: Bool)

    // MARK: - Error Events
    /// Fired when an error occurs.
    case errorOccurred(error: Error)

    // MARK: - Custom Events
    /// A custom event with an identifier and an associated parameters dictionary for maximum flexibility.
    case custom(identifier: String, params: [String: Any])
}

/**
 Represents a trigger for an agent that monitors a set of conditions and emits an event when they are met.
 
 When the trigger is evaluated with the current context, if all of its conditions are satisfied, it creates
 a TriggerEvent and executes its action closure. This design decouples condition evaluation from the resulting action,
 allowing the agent to later route the emitted event to a particular skill.
 */
public struct AgentTrigger: AgentComponent {
    /// The unique identifier for the trigger.
    public let id: UUID
    
    /// An array of conditions that must all be met for the trigger to fire.
    public let conditions: [TriggerConditionProtocol]
    
    /// The action to execute when all conditions are met. The closure receives the emitted TriggerEvent.
    public let action: (TriggerEvent) -> Void
    
    /**
     Initializes a new AgentTrigger.
     
     - Parameters:
       - conditions: An array of trigger conditions.
       - action: A closure to execute when the trigger fires. The closure is provided with the TriggerEvent.
     */
    public init(conditions: [TriggerConditionProtocol], action: @escaping (TriggerEvent) -> Void) {
        self.id = UUID()
        self.conditions = conditions
        self.action = action
    }
    
    /**
     Evaluates the trigger's conditions against a provided context. If all conditions are met, emits a TriggerEvent
     (using the custom event type) and executes the action.
     
     - Parameter context: A dictionary containing the current contextual data.
     */
    public func evaluate(context: [String: Any]?) {
        if conditions.allSatisfy({ $0.evaluate(context: context) }) {
            let event = TriggerEvent(triggerID: id, eventType: .custom(identifier: "triggerFired", params: context ?? [:]))
            action(event)
        }
    }
    
    /**
     Converts this AgentTrigger into an Agent.Component for declarative agent construction.
     
     - Returns: An Agent.Component representing this trigger.
     */
    public func toComponent() -> Agent.Component {
        return .trigger(self)
    }
}
