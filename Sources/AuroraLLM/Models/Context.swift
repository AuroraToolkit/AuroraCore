//
//  Context.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/20/24.
//

import Foundation

/**
 Represents the entire context for a conversation or task.

 A `Context` stores a collection of `ContextItem` instances and `Bookmark` instances,
 which represent the content and notable points in a conversation or task.
 The context is uniquely identified by its `UUID` and contains metadata about the associated LLM service.
 */
public struct Context: Codable, Equatable {
    /// Unique identifier for the context.
    public let id: UUID

    /// A collection of `ContextItem` instances that make up the content of the context.
    public private(set) var items: [ContextItem] = []

    /// A collection of `Bookmark` instances within the context.
    public private(set) var bookmarks: [Bookmark] = []

    /// The name of the LLM service vendor associated with this context.
    public var llmServiceVendor: String

    /// The creation date for the context.
    public let creationDate: Date

    /**
     Initializes a new `Context` with a unique identifier and associated LLM service information.

     - Parameters:
        - llmServiceVendor: The name of the LLM service vendor associated with this context.
        - creationDate: The date when the context was created. Defaults to the current date.
     */
    public init(llmServiceVendor: String, creationDate: Date = Date()) {
        id = UUID()
        self.llmServiceVendor = llmServiceVendor
        self.creationDate = creationDate
    }

    /**
     Adds a new item to the context.

     - Parameters:
        - content: The content of the new `ContextItem`.
        - creationDate: The date the item was created (default is the current date).
        - isSummary: A flag indicating whether the item is a summary (default is `false`).
     */
    public mutating func addItem(content: String, creationDate: Date = Date(), isSummary: Bool = false) {
        let newItem = ContextItem(text: content, creationDate: creationDate, isSummary: isSummary)
        items.append(newItem)
    }

    /**
     Adds a new bookmark to the context for a specific item.

     - Parameters:
        - item: The `ContextItem` to be bookmarked.
        - label: A label describing the purpose of the bookmark.
     */
    public mutating func addBookmark(for item: ContextItem, label: String) {
        let newBookmark = Bookmark(contextItemID: item.id, label: label)
        bookmarks.append(newBookmark)
    }

    /**
     Retrieves a `ContextItem` by its unique identifier.

     - Parameter id: The unique identifier of the item.

     - Returns: The `ContextItem` if found, otherwise `nil`.
     */
    public func getItem(by id: UUID) -> ContextItem? {
        return items.first(where: { $0.id == id })
    }

    /**
     Retrieves a `Bookmark` by its unique identifier.

     - Parameter id: The unique identifier of the bookmark.

     - Returns: The `Bookmark` if found, otherwise `nil`.
     */
    public func getBookmark(by id: UUID) -> Bookmark? {
        return bookmarks.first(where: { $0.id == id })
    }

    /**
     Removes items from the context by their index set.

     - Parameter offsets: An `IndexSet` of the items to be removed.
     */
    public mutating func removeItems(atOffsets offsets: IndexSet) {
        for index in offsets.reversed() {
            items.remove(at: index)
        }
    }

    /**
     Updates an item within the context.

     - Parameter updatedItem: The `ContextItem` to be updated.
     */
    public mutating func updateItem(_ updatedItem: ContextItem) {
        if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
            items[index] = updatedItem
        }
    }

    /**
     Retrieves the most recent `N` items from the context.

     - Parameter limit: The number of recent items to retrieve.

     - Returns: An array of the most recent `ContextItem` instances.
     */
    public func getRecentItems(limit: Int) -> [ContextItem] {
        return Array(items.suffix(limit))
    }

    /**
     Summarizes a range of items within the context and replaces them with a summary item.

     - Parameters:
        - range: The range of items to summarize.
        - summarizer: A closure that summarizes the text content of the items.
     */
    public mutating func summarizeItemsInRange(range: Range<Int>, summarizer: (String) -> String) {
        let groupText = items[range].map { $0.text }.joined(separator: "\n")
        let summary = summarizer(groupText)
        let summaryItem = ContextItem(text: summary, isSummary: true)

        // Remove the original items and replace them with the summary
        items.replaceSubrange(range, with: [summaryItem])
    }

    /**
     Conformance to `Equatable` for comparison between contexts.

     - Parameters:
        - lhs: The left-hand side `Context` to compare.
        - rhs: The right-hand side `Context` to compare.

     - Returns: `true` if the contexts are equal, otherwise `false`.
     */
    public static func == (lhs: Context, rhs: Context) -> Bool {
        return lhs.id == rhs.id &&
            lhs.items == rhs.items &&
            lhs.bookmarks == rhs.bookmarks &&
            lhs.llmServiceVendor == rhs.llmServiceVendor &&
            abs(lhs.creationDate.timeIntervalSince(rhs.creationDate)) < 1.0 // Ignore differences smaller than 1 second
    }
}
