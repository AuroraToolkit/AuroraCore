//
//  RSSParsingTask.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/3/24.
//

import Foundation
import os.log

/**
 `RSSParsingTask` parses an RSS feed and extracts the article links.

 - **Inputs**
    - `feedData`: The data of the RSS feed to parse.
 - **Outputs**
    - `articles`: An array of `RSSArticle` objects containing the article details.

 This task can be integrated into a workflow where article links need to be extracted from an RSS feed.
 */
public class RSSParsingTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    private var articleLinks: [String] = []
    private var currentElement: String = ""
    private var currentLink: String?

    /**
     Initializes the `RSSParsingTask` with the RSS feed data.

     - Parameters:
        - name: The name of the task (default is `RSSParsingTask`).
        - feedData: The data of the RSS feed to parse.
        - inputs: Additional inputs for the task. Defaults to an empty dictionary.

     - Note: The `inputs` array can contain direct values for keys like `feedData`, or dynamic references that will be resolved at runtime.
     */
    public init(
        name: String? = nil,
        feedData: Data? = nil,
        inputs: [String: Any?] = [:]
    ) {
        self.task = Workflow.Task(
            name: name,
            description: "Extract article links from the RSS feed",
            inputs: inputs
        ) { inputs in
            /// Resolve the feedData from the inputs if it exists, otherwise use the provided `feedData` parameter or default
            let resolvedFeedData = inputs.resolve(key: "feedData", fallback: feedData)

            // Validate the input data
            guard let feedData = resolvedFeedData, !feedData.isEmpty else {
                throw NSError(domain: "RSSParsingTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid RSS feed data"])
            }

            // Initialize the parser
            let parserDelegate = RSSParserDelegate()
            let parser = XMLParser(data: feedData)
            parser.delegate = parserDelegate

            // Start parsing
            guard parser.parse() else {
                let parseError = parser.parserError?.localizedDescription ?? "Unknown error"
                throw NSError(domain: "RSSParsingTask", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse RSS feed: \(parseError)"])
            }

            print("Parsed \(parserDelegate.articles.count) articles")

            return ["articles": parserDelegate.articles]
        }
    }

    /// Converts this `RSSParsingTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}

/**
    `RSSArticle` represents an article extracted from an RSS feed.
*/
public struct RSSArticle {
    /// The title of the article.
    public let title: String

    /// The link to the article.
    public let link: String

    /// The description of the article.
    public let description: String

    /// The GUID of the article.
    public let guid: String
}

/**
    The `RSSParserDelegate` class is responsible for parsing the RSS feed XML data.
 */
fileprivate class RSSParserDelegate: NSObject, XMLParserDelegate {

    var articles: [RSSArticle] = []
    private var currentElement: String = ""
    private var currentTitle: String = ""
    private var currentLink: String = ""
    private var currentDescription: String = ""
    private var currentGUID: String = ""
    private var insideItem: Bool = false

    // MARK: - XMLParserDelegate Methods

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        currentElement = elementName
        if elementName == "item" {
            insideItem = true
            currentLink = ""
            currentDescription = ""
            currentGUID = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem else { return }

        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        switch currentElement {
            case "title":
            currentTitle += trimmedString
        case "link":
            currentLink += trimmedString
        case "description":
            currentDescription += trimmedString
        case "guid":
            currentGUID += trimmedString
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if elementName == "item" {
            // Validate the article before adding. Skip if title or link is empty
            if !currentTitle.isEmpty && !currentLink.isEmpty {
                let article = RSSArticle(
                    title: currentTitle,
                    link: currentLink,
                    description: currentDescription,
                    guid: currentGUID
                )
                articles.append(article)
            }

            // Reset current variables for the next item
            currentTitle = ""
            currentLink = ""
            currentDescription = ""
            currentGUID = ""

            insideItem = false
        }
        currentElement = ""
    }
}
