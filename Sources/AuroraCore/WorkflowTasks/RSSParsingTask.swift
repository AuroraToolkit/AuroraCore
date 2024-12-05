//
//  RSSParsingTask.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/3/24.
//

import Foundation

/**
 `RSSParsingTask` parses an RSS feed and extracts the article links.

 - **Inputs**
    - `feedData`: The data of the RSS feed to parse.
 - **Outputs**
    - `articles`: An array of `RSSArticle` objects containing the article details.

 This task can be integrated into a workflow where article links need to be extracted from an RSS feed.
 */
public class RSSParsingTask: WorkflowTask {
    private var articleLinks: [String] = []
    private var currentElement: String = ""
    private var currentLink: String?

    /**
     Initializes the `RSSParsingTask` with the RSS feed data.

     - Parameter feedData: The data of the RSS feed to parse.
     */
    public init(feedData: Data) {
        super.init(
            name: "Parse RSS Feed",
            description: "Extract article links from the RSS feed",
            inputs: ["feedData": feedData]
        )
    }

    public override func execute() async throws -> [String: Any] {
        // Validate the input data
        guard let feedData = inputs["feedData"] as? Data else {
            markFailed()
            throw NSError(domain: "RSSParsingTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid RSS feed data"])
        }

        // Initialize the parser
        let parserDelegate = RSSParserDelegate()
        let parser = XMLParser(data: feedData)
        parser.delegate = parserDelegate

        // Start parsing
        guard parser.parse() else {
            markFailed()
            throw NSError(domain: "RSSParsingTask", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse RSS feed"])
        }

        markCompleted()
        return ["articles": parserDelegate.articles]
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
            // Store the parsed article details
            let article = RSSArticle(
                title: currentTitle,
                link: currentLink,
                description: currentDescription,
                guid: currentGUID
            )
            articles.append(article)
            insideItem = false
        }
        currentElement = ""
    }
}
