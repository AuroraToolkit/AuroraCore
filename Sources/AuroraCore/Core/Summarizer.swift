//
//  Summarizer.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/21/24.
//

import Foundation

/**
 A protocol that defines the interface for summarizing text.

 Conforming types must implement methods for summarizing a single block of text, as well as summarizing a collection of `ContextItem` objects.
 */
public protocol Summarizer {

    /**
     Summarizes a single block of text.

     - Parameter text: The input text to be summarized.
     - Returns: The summarized text.
     */
    func summarize(_ text: String) -> String

    /**
     Summarizes a collection of `ContextItem` objects.

     This method combines the text of multiple `ContextItem` objects and returns a summarized version of the combined text.

     - Parameter items: An array of `ContextItem` objects to be summarized.
     - Returns: The summarized text.
     */
    func summarizeItems(_ items: [ContextItem]) -> String
}
