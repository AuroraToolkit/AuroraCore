//
//  ContextController.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/21/24.
//

import Foundation

/**
 `ContextController` manages the state and operations related to a specific `Context`, including adding, removing, and updating items, as well as summarizing older items. Each `ContextController` can handle a specific summarizer and manages the token limits for summarization.
 */
public class ContextController {

    /// Unique identifier for the context controller.
    public let id: UUID

    /// The context managed by this controller.
    private var context: Context

    /// A collection of summarized context items.
    private var summarizedItems: [ContextItem] = []

    /// Maximum token limit allowed for summarization.
    private let maxTokenLimit: Int

    /// Summarizer instance responsible for summarizing context items.
    private let summarizer: Summarizer

    /**
     Initializes a new `ContextController` instance.

     - Parameters:
        - context: Optional `Context` object. If none is provided, a new context will be created automatically.
        - maxTokenLimit: Maximum token limit for the context's `TokenManager`.
        - summarizer: Optional `Summarizer` instance. If none is provided, a default summarizer will be created.
     */
    public init(context: Context? = nil, maxTokenLimit: Int, summarizer: Summarizer? = nil) {
        self.id = UUID()
        self.context = context ?? Context()
        self.maxTokenLimit = maxTokenLimit
        self.summarizer = summarizer ?? DefaultSummarizer()
    }

    /**
     Adds a new item to the context.

     - Parameters:
        - content: The content of the item to be added.
        - creationDate: The date when the item was created. Defaults to the current date.
     */
    public func addItem(content: String, creationDate: Date = Date()) {
        context.addItem(content: content, creationDate: creationDate)
    }

    /**
     Adds a bookmark to the context for a specific item.

     - Parameters:
        - item: The `ContextItem` to be bookmarked.
        - label: A label for the bookmark.
     */
    public func addBookmark(for item: ContextItem, label: String) {
        context.addBookmark(for: item, label: label)
    }

    /**
     Removes items from the context based on their offsets.

     - Parameters:
        - offsets: The index set of the items to be removed.
     */
    public func removeItems(atOffsets offsets: IndexSet) {
        context.removeItems(atOffsets: offsets)
    }

    /**
     Updates an existing item in the context.

     - Parameters:
        - updatedItem: The updated `ContextItem` to replace the old item.
     */
    public func updateItem(_ updatedItem: ContextItem) {
        context.updateItem(updatedItem)
    }

    /**
     Summarizes older context items that are more than 7 days old. Groups and summarizes items while adhering to token limits.
     */
    public func summarizeOlderContext() {
        guard !context.items.isEmpty else {
            return
        }

        var group: [ContextItem] = []
        var groupTokenCount = 0

        for item in context.items where !item.isSummarized && item.isOlderThan(days: 7) {
            group.append(item)
            groupTokenCount += item.tokenCount

            if groupTokenCount >= maxTokenLimit / 2 {
                summarizeGroup(group)
                group.removeAll()
                groupTokenCount = 0
            }
        }

        if !group.isEmpty {
            summarizeGroup(group)
        }
    }

    /**
     Summarizes a group of context items and stores the result in `summarizedItems`.

     - Parameters:
        - group: The array of `ContextItem` to be summarized.
     */
    private func summarizeGroup(_ group: [ContextItem]) {
        let summary: String

        if group.count == 1 {
            summary = summarizer.summarize(group[0].text)
        } else {
            summary = summarizer.summarizeItems(group)
        }

        let summaryItem = ContextItem(text: summary, isSummary: true)
        summarizedItems.append(summaryItem)

        for item in group {
            var updatedItem = item
            updatedItem.isSummarized = true
            context.updateItem(updatedItem)
        }
    }

    /**
     Retrieves the full history of context items.

     - Returns: An array of `ContextItem` representing the full history.
     */
    public func fullHistory() -> [ContextItem] {
        return context.items
    }

    /**
     Retrieves the summarized context items.

     - Returns: An array of `ContextItem` representing the summarized items.
     */
    public func summarizedContext() -> [ContextItem] {
        return summarizedItems
    }

    /**
     Exposes the context items for testing purposes.

     - Returns: An array of `ContextItem`.
     */
    public func getItems() -> [ContextItem] {
        return context.items
    }

    /**
     Exposes the bookmarks for testing purposes.

     - Returns: An array of `Bookmark`.
     */
    public func getBookmarks() -> [Bookmark] {
        return context.bookmarks
    }

    /**
     Exposes the underlying context for testing or external use.

     - Returns: The `Context` instance.
     */
    public func getContext() -> Context {
        return context
    }

    /**
     Exposes the summarizer used by the `ContextController`.

     - Returns: The `Summarizer` instance.
     */
    public func getSummarizer() -> Summarizer {
        return summarizer
    }
}
