//
//  JSONParsingTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/13/25.
//

import Foundation
import os.log
import AuroraCore

/**
 `JSONParsingTask` parses a JSON blob and extracts its nested structure into a `JSONElement`.

 - **Inputs**
    - `jsonData`: The data of the JSON to parse.
 - **Outputs**
    - `parsedJSON`: The root `JSONElement` containing the parsed details.

 This task is general-purpose and can handle any JSON structure.
 */
public class JSONParsingTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /**
     Initializes the `JSONParsingTask`.

     - Parameters:
        - name: The name of the task (default is `JSONParsingTask`).
        - jsonData: The JSON data to parse.
        - inputs: Additional inputs for the task. Defaults to an empty dictionary.
     */
    public init(
        name: String? = nil,
        jsonData: Data? = nil,
        inputs: [String: Any?] = [:]
    ) {
        self.task = Workflow.Task(
            name: name ?? String(describing: Self.self),
            description: "Parse JSON data into a nested structure",
            inputs: inputs
        ) { inputs in
            // Resolve the JSON data input
            let resolvedJSONData = inputs.resolve(key: "jsonData", fallback: jsonData)

            // Validate input
            guard let jsonData = resolvedJSONData, !jsonData.isEmpty else {
                throw NSError(domain: "JSONParsingTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid JSON data"])
            }

            // Parse the JSON data
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
            let jsonElement = JSONElement(from: jsonObject)

            return ["parsedJSON": jsonElement]
        }
    }

    /// Converts this `JSONParsingTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}

/**
    A representation of a JSON element for structured JSON parsing.

    This enum can represent any JSON structure, including objects, arrays, strings, numbers, booleans, and null values.
 */
public enum JSONElement: Equatable {
    case object([String: JSONElement])
    case array([JSONElement])
    case string(String)
    case number(NSNumber)   // All numeric values, including booleans as 0(false)/1(true)
    case null

    init(from jsonObject: Any) {
        if let dictionary = jsonObject as? [String: Any] {
            self = .object(dictionary.mapValues { JSONElement(from: $0) })
        } else if let array = jsonObject as? [Any] {
            self = .array(array.map { JSONElement(from: $0) })
        } else if let string = jsonObject as? String {
            self = .string(string)
        } else if let number = jsonObject as? NSNumber {
            self = .number(number)
        } else {
            self = .null
        }
    }

    /// Debug description for pretty-printing the JSON element.
    public var debugDescription: String {
        switch self {
        case .object(let dictionary):
            return "{\(dictionary.map { "\($0): \($1.debugDescription)" }.joined(separator: ", "))}"
        case .array(let array):
            return "[\(array.map { $0.debugDescription }.joined(separator: ", "))]"
        case .string(let string):
            return "\"\(string)\""
        case .number(let number):
            return "\(number)"
        case .null:
            return "null"
        }
    }
}

