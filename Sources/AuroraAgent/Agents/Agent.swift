//
//  Agent.swift
//  AuroraAgent
//
//  Created by Dan Murrell Jr on 3/19/25.
//

import Foundation

/**
 A declarative representation of an agent, consisting of skills and capabilities.

 The `Agent` struct allows developers to define complex agents using a clear and concise declarative syntax.
 Agents are composed of individual skills, which are reusable components that define specific tasks or capabilities.
 */
public struct Agent {
    /// The unique identifier for the agent.
    public let id: UUID

    /// The name of the agent.
    public let name: String

    /// A description of the agent.
    public let description: String

    /// Instructions for the agent (similar to a system prompt in an LLM) that describes the agent's personality and behavior.
    public let instructions: String

    /// The context data for the agent, which can be used to provide dynamic information during operation.
    public let context: [String: Any]

    /// The memory of the agent, storing information about past interactions and context.
    public let memory: AgentMemory

    /// The personality of the agent, which can influence its communication style and behavior.
    public let personality: Personality

    /// The agent's lifecycle events, such as initialization and teardown.
    public let lifecycle: Lifecycle

    /// An array of skills available to the agent.
    public let skills: [Skill]

    /// An array of triggers that the agent can respond to.
    public let triggers: [AgentTrigger]

    /// The queue used for processing queries.
    private let queue: Agent.Queue


    /**
     Initializes a new `Agent` with the specified name, description, and declaratively defined components.

     This initializer leverages the `AgentBuilder` result builder to generate the agent's components.
     For components that must be unique (e.g., memory), if more than one is defined, only the first is used.
     For instructions, multiple components are concatenated with a newline separator.

     - Parameters:
        - name: The name of the agent.
        - description: A brief description of the agent.
        - builder: A closure that produces an array of `Agent.Component` values.
     */
    public init(
        name: String,
        description: String,
        @AgentBuilder builder: () -> [Agent.Component]
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.queue = Agent.Queue()

        let components = builder()
        var instructionValues: [String] = []
        var combinedContext: [String: Any] = [:]
        var memoryInstance: AgentMemory? = nil
        var personalityInstance: Personality? = nil
        var lifecycleInstance: Lifecycle? = nil
        var skillValues: [Skill] = []
        var triggerValues: [AgentTrigger] = []

        // Process each declarative component.
        for component in components {
            switch component {
            case .instructions(let instr):
                instructionValues.append(instr)
            case .context(let ctx):
                // Merge with combinedContext; later keys overwrite earlier ones.
                combinedContext.merge(ctx.data) { (_, new) in new }
            case .memory(let mem):
                // Use the first memory component defined.
                if memoryInstance == nil {
                    memoryInstance = mem
                }
            case .personality(let personality):
                // Use the first personality component defined.
                if personalityInstance == nil {
                    personalityInstance = personality
                }
            case .lifecycle(let lifecycle):
                // Use the first lifecycle component defined.
                if lifecycleInstance == nil {
                    lifecycleInstance = lifecycle
                }
            case .skill(let skill):
                skillValues.append(skill)
            case .skillGroup(let group):
                // Append skills from the group.
                skillValues.append(contentsOf: group.skills)
            case .trigger(let trigger):
                // Append triggers to the triggerValues array.
                triggerValues.append(trigger)
            }
        }

        // Combine multiple instructions into one string, separated by newlines.
        self.instructions = instructionValues.isEmpty ? "" : instructionValues.joined(separator: "\n")
        self.context = combinedContext
        // Use the first defined memory component, or create a new one if none is provided.
        self.memory = memoryInstance ?? AgentMemory()
        // Use the first defined personality component, or create a new one if none is provided.
        self.personality = personalityInstance ?? Personality(name: "Default", description: "A generic agent.", tone: .friendly)
        // Use the first defined lifecycle component, or nil if none is provided.
        self.lifecycle = lifecycleInstance ?? Lifecycle()
        // Set the agent's skills.
        self.skills = skillValues
        // Set the agent's triggers.
        self.triggers = triggerValues

        // Execute the lifecycle onInit closure if defined.
        self.lifecycle.onInit?()
    }

    /**
     Executes the onTeardown lifecycle hook, if defined.

     Call this method when the agent is no longer needed to perform cleanup tasks.
     */
    public func shutdown() {
        lifecycle.onTeardown?()
    }

    /**
     Processes a query using the agent's internal queue and returns a response.

     - Parameter query: The input query.
     - Returns: A response string after processing the query.
     */
    public func query(_ query: String) async -> String {
        let response = await queue.enqueue(query: query) { query in
            // Simulate processing delay (for demonstration)
            try? await Task.sleep(nanoseconds: 200_000_000) // 200 ms delay
            let response = "Response for query: \(query)"
            // Save the query/response in memory.
            let event = AgentMemory.Event(eventType: .queryReceived(query: query), message: nil)
            await self.memory.addEvent(event)
            await self.memory.addResponse(for: event.id, response: response)
            return response
        }
        return response
    }

    // MARK: - Nested Types

    /**
     Represents a building block of an agent, for example a description, skill, or a skill group.
     */
    public enum Component {
        /// Component to define instructions for the agent.
        case instructions(String)

        /// Component to define context data for the agent.
        case context(Context)

        /// Component to define the memory for the agent.
        case memory(AgentMemory)

        /// Component to define the agent's personality.
        case personality(Personality)

        /// Component to define lifecycle events for the agent.
        case lifecycle(Lifecycle)

        /// Component to define a skill that the agent can perform.
        case skill(Skill)

        /// Component to define a group of skills.
        case skillGroup(SkillGroup)

        /// Component to define an expected trigger for the agent.
        case trigger(AgentTrigger)
    }

    // MARK: - Instructions

    /**
     Represents instructions for the agent (similar to a system prompt in an LLM).

     Instructions describe the agent's personality and behavior.
     */
    public struct Instructions: AgentComponent {
        /// A unique identifier for the instructions.
        public let id: UUID

        /// The instructions for the agent.
        public let instructions: String

        /**
         Initializes a new `Instructions` object.

         - Parameter instructions: The instructions for the agent.
         */
        public init(_ instructions: String) {
            self.id = UUID()
            self.instructions = instructions
        }

        public func toComponent() -> Agent.Component {
            .instructions(instructions)
        }
    }

    // MARK: - Context

    /**
     Represents context data for an agent in AuroraToolkit.

     The Context component encapsulates dynamic environmental or runtime information as key-value pairs
     that the agent and its skills can leverage during operation.
     */
    public struct Context: AgentComponent {
        /// A unique identifier for the context component.
        public let id: UUID

        /// A dictionary containing the contextual data.
        public let data: [String: Any]

        /**
         Initializes a new Context component.

         - Parameter data: A dictionary containing the context data.
         */
        public init(data: [String: Any]) {
            self.id = UUID()
            self.data = data
        }

        /**
         Converts this Context into an Agent.Component for declarative agent construction.

         - Returns: An Agent.Component representing this context.
         */
        public func toComponent() -> Agent.Component {
            return .context(self)
        }
    }

    // MARK: - Personality

    public struct Personality: AgentComponent {
        /// A unique identifier for the personality.
        public let id: UUID

        /// A short name or label for the personality.
        public let name: String

        /// A detailed description of the personality, used to inform the agent's communication style.
        public let description: String

        /// The overall tone of the personality (e.g., friendly, formal, humorous, empathetic).
        public let tone: Tone

        /// A list of traits (keywords or adjectives) that further describe the personality.
        public let traits: [String]

        /// Optionally, the language style preference (e.g., concise, technical, elaborate).
        public let languageStyle: String?

        /**
         Initializes a new Personality component.

         - Parameters:
           - name: A short name for the personality.
           - description: A detailed description of the personality.
           - tone: The overall tone of the personality.
           - traits: An array of traits that describe the personality.
           - languageStyle: Optional preference for language style.
         */
        public init(
            name: String,
            description: String,
            tone: Tone,
            traits: [String] = [],
            languageStyle: String? = nil
        ) {
            self.id = UUID()
            self.name = name
            self.description = description
            self.tone = tone
            self.traits = traits
            self.languageStyle = languageStyle
        }

        /**
         Converts this Personality into an Agent.Component for declarative agent construction.

         - Returns: An Agent.Component representing this personality.
         */
        public func toComponent() -> Agent.Component {
            // Assuming a case `.personality(Personality)` exists in Agent.Component
            return .personality(self)
        }

        /**
         Converts the personality data into a prompt string suitable for inclusion with an LLM.

         - Returns: A string that encapsulates the personality's characteristics as part of the system prompt.
         */
        public func toLLMPrompt() -> String {
            var prompt = "You are \(name). "
            prompt += description.isEmpty ? "" : "\(description) "
            prompt += "Your tone should be \(tone.rawValue)."

            if !traits.isEmpty {
                prompt += " You are known to be " + traits.joined(separator: ", ") + "."
            }

            if let style = languageStyle, !style.isEmpty {
                prompt += " Please respond in a \(style) manner."
            }
            return prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        /// Enumerates the possible tones for a personality.
        public enum Tone: String {
            /// Friendly and approachable.
            case friendly
            /// Formal and professional.
            case formal
            /// Humorous and lighthearted.
            case humorous
            /// Empathetic and understanding.
            case empathetic
            /// Authoritative and commanding.
            case authoritative
        }
    }

    // MARK: - Lifecycle Events

    /**
     Represents lifecycle hooks for an agent.

     This component defines actions to be performed during agent initialization or teardown,
     such as setting up resources or cleaning up state.
     */
    public struct Lifecycle: AgentComponent {
        /// A unique identifier for the lifecycle component.
        public let id: UUID
        /// A closure executed when the agent is initialized.
        public let onInit: (() -> Void)?
        /// A closure executed when the agent is torn down.
        public let onTeardown: (() -> Void)?

        /**
         Initializes a new Lifecycle component.

         - Parameters:
           - onInit: An optional closure executed upon agent initialization.
           - onTeardown: An optional closure executed upon agent teardown.
         */
        public init(onInit: (() -> Void)? = nil, onTeardown: (() -> Void)? = nil) {
            self.id = UUID()
            self.onInit = onInit
            self.onTeardown = onTeardown
        }

        public func toComponent() -> Agent.Component {
            return .lifecycle(self)
        }
    }

    // MARK: - Skill

    /**
     Represents a skill that the agent can perform.

     Skills are reusable components that define specific tasks or capabilities.
     */
    public struct Skill: AgentComponent {
        /// A unique identifier for the skill.
        public let id: UUID

        /// The name of the skill.
        public let name: String

        /// A brief description of the skill.
        public let description: String

        public func toComponent() -> Agent.Component {
            .skill(self)
        }
    }

    // MARK: - Skill Group

    /**
     Represents a group of skills that the agent can perform.

     Skill groups are reusable components that define specific tasks or capabilities.
     */
    public struct SkillGroup: AgentComponent {
        /// A unique identifier for the skill group.
        public let id: UUID

        /// The name of the skill group.
        public let name: String

        /// A brief description of the skill group.
        public let description: String

        /// The skills contained in the skill group.
        public let skills: [Skill]

        public func toComponent() -> Agent.Component {
            .skillGroup(self)
        }
    }

    // MARK: - Queue

    private actor Queue {
        func enqueue(query: String, processor: (String) async -> String) async -> String {
            // Serial execution is guaranteed by actor isolation.
            return await processor(query)
        }
    }
}
