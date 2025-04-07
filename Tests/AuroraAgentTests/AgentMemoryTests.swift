//
//  AgentMemoryTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 3/23/25.
//


import XCTest
@testable import AuroraAgent

final class AgentMemoryTests: XCTestCase {

    // Test default sorting by timestamp (ascending order)
    func testGetHistorySortedByDefaultTimestampAscending() async {
        let memory = AgentMemory()
        
        // Add entries with a slight delay so that their timestamps differ
        await memory.addQuery("first", response: "response1")
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 sec delay
        await memory.addQuery("second", response: "response2")
        try? await Task.sleep(nanoseconds: 100_000_000)
        await memory.addQuery("third", response: "response3")

        // Retrieve history sorted by timestamp in ascending order (default behavior)
        let sortedHistory = await memory.getHistory(sortedBy: { $0.timestamp < $1.timestamp })
        // Filter for events of type queryReceived and extract the query string
        let queries = sortedHistory.compactMap { event -> String? in
            if case let .queryReceived(query) = event.eventType {
                return query
            }
            return nil
        }

        XCTAssertEqual(queries, ["first", "second", "third"], "History should be sorted in ascending order by timestamp")
    }

    // Test custom sorting by timestamp in descending order
    func testGetHistorySortedByTimestampDescending() async {
        let memory = AgentMemory()
        
        await memory.addQuery("first", response: "response1")
        try? await Task.sleep(nanoseconds: 100_000_000)
        await memory.addQuery("second", response: "response2")
        try? await Task.sleep(nanoseconds: 100_000_000)
        await memory.addQuery("third", response: "response3")

        let sortedDescending = await memory.getHistory(sortedBy: { $0.timestamp > $1.timestamp })
        // Filter for events of type queryReceived and extract the query string
        let queries = sortedDescending.compactMap { event -> String? in
            if case let .queryReceived(query) = event.eventType {
                return query
            }
            return nil
        }
        XCTAssertEqual(queries, ["third", "second", "first"], "History should be sorted in descending order by timestamp")
    }
    
    // Test custom sorting by the query string in lexicographical order
    func testGetHistorySortedByQueryLexicographically() async {
        let memory = AgentMemory()
        
        await memory.addQuery("banana", response: "yellow")
        await memory.addQuery("apple", response: "red")
        await memory.addQuery("cherry", response: "red")

        let queries = await memory.getHistory().compactMap { event -> String? in
                if case let .queryReceived(query) = event.eventType {
                    return query
                }
                return nil
            }
            .sorted(by: { $0 < $1 })

        XCTAssertEqual(queries, ["apple", "banana", "cherry"], "History should be sorted lexicographically by query")
    }
    
    // Test custom sorting using a different comparator (e.g. by response in descending order)
    func testGetHistorySortedByCustomComparator() async {
        let memory = AgentMemory()
        
        await memory.addQuery("A", response: "1")
        await memory.addQuery("B", response: "2")
        await memory.addQuery("C", response: "3")
        
        // Sort by response (as strings) in descending order
        let responses = await memory.getAllResponses()
            .map( {$0.value })
            .sorted(by: { $0 > $1 })

        XCTAssertEqual(responses, ["3", "2", "1"], "History should be sorted in descending order by response")
    }
}
