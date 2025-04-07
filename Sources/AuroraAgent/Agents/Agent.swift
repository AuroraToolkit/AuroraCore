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

    /// The memory of the agent, storing information about past interactions and context.
    public let memory: AgentMemory

    /// The queue used for processing queries.
    private let queue: Agent.Queue

    /// An array of skills available to the agent.
    public let skills: [Skill]

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
        var memoryInstance: AgentMemory? = nil
        var skillValues: [Skill] = []

        // Process each declarative component.
        for component in components {
            switch component {
            case .instructions(let instr):
                instructionValues.append(instr)
            case .memory(let mem):
                // Use the first memory component defined.
                if memoryInstance == nil {
                    memoryInstance = mem
                }
            case .skill(let skill):
                skillValues.append(skill)
            case .skillGroup(let group):
                // Append skills from the group.
                skillValues.append(contentsOf: group.skills)
            }
        }

        // Combine multiple instructions into one string, separated by newlines.
        self.instructions = instructionValues.isEmpty ? "" : instructionValues.joined(separator: "\n")
        // Use the first defined memory component, or create a new one if none is provided.
        self.memory = memoryInstance ?? AgentMemory()
        // Set the agent's skills.
        self.skills = skillValues
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

        /// Component to define a skill that the agent can perform.
        case skill(Skill)

        /// Component to define a group of skills.
        case skillGroup(SkillGroup)

        /// Component to define the memory for the agent.
        case memory(AgentMemory)
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
