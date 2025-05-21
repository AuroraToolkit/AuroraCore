//
//  Bookmark.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/20/24.
//

import Foundation

/**
 Represents a bookmark within the context, linking to a specific `ContextItem` by its ID.

 Bookmarks store a label, timestamp, and the ID of the associated context item, providing a way to mark important moments or pieces of content within the context.
 */
public struct Bookmark: Identifiable, Codable, Equatable {
    /// Unique identifier for the bookmark.
    public let id: UUID

    /// The ID of the associated context item.
    public let contextItemID: UUID

    /// A label describing the bookmark's purpose or content.
    public let label: String

    /// The timestamp when the bookmark was created.
    public let timestamp: Date

    /**
     Initializes a new bookmark for a given context item with a specified label.

     - Parameters:
        - contextItemID: The ID of the `ContextItem` this bookmark refers to.
        - label: A descriptive label for the bookmark.
     */
    public init(contextItemID: UUID, label: String) {
        id = UUID()
        self.contextItemID = contextItemID
        self.label = label
        timestamp = Date()
    }

    /**
     Equatable conformance for `Bookmark`.

     Two bookmarks are considered equal if they have the same ID, context item ID, label, and timestamp.

     - Parameters:
        - lhs: The first bookmark to compare.
        - rhs: The second bookmark to compare.

     - Returns: `true` if the bookmarks are equal, otherwise `false`.
     */
    public static func == (lhs: Bookmark, rhs: Bookmark) -> Bool {
        return lhs.id == rhs.id &&
            lhs.contextItemID == rhs.contextItemID &&
            lhs.label == rhs.label &&
            lhs.timestamp == rhs.timestamp
    }
}
