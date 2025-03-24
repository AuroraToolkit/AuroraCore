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
        await memory.addEntry(query: "first", response: "response1")
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 sec delay
        await memory.addEntry(query: "second", response: "response2")
        try? await Task.sleep(nanoseconds: 100_000_000)
        await memory.addEntry(query: "third", response: "response3")

        // Retrieve history sorted by timestamp in ascending order (default behavior)
        let sortedHistory = await memory.getHistory(sortedBy: { $0.timestamp < $1.timestamp })
        let queries = sortedHistory.map { $0.query ?? "" }
        
        XCTAssertEqual(queries, ["first", "second", "third"], "History should be sorted in ascending order by timestamp")
    }

    // Test custom sorting by timestamp in descending order
    func testGetHistorySortedByTimestampDescending() async {
        let memory = AgentMemory()
        
        await memory.addEntry(query: "first", response: "response1")
        try? await Task.sleep(nanoseconds: 100_000_000)
        await memory.addEntry(query: "second", response: "response2")
        try? await Task.sleep(nanoseconds: 100_000_000)
        await memory.addEntry(query: "third", response: "response3")

        let sortedDescending = await memory.getHistory(sortedBy: { $0.timestamp > $1.timestamp })
        let queries = sortedDescending.map { $0.query ?? "" }
        
        XCTAssertEqual(queries, ["third", "second", "first"], "History should be sorted in descending order by timestamp")
    }
    
    // Test custom sorting by the query string in lexicographical order
    func testGetHistorySortedByQueryLexicographically() async {
        let memory = AgentMemory()
        
        await memory.addEntry(query: "banana", response: "yellow")
        await memory.addEntry(query: "apple", response: "red")
        await memory.addEntry(query: "cherry", response: "red")

        let sortedByQuery = await memory.getHistory(sortedBy: { ($0.query ?? "") < ($1.query ?? "") })
        let queries = sortedByQuery.map { $0.query ?? "" }
        
        XCTAssertEqual(queries, ["apple", "banana", "cherry"], "History should be sorted lexicographically by query")
    }
    
    // Test custom sorting using a different comparator (e.g. by response in descending order)
    func testGetHistorySortedByCustomComparator() async {
        let memory = AgentMemory()
        
        await memory.addEntry(query: "A", response: "1")
        await memory.addEntry(query: "B", response: "2")
        await memory.addEntry(query: "C", response: "3")
        
        // Sort by response (as strings) in descending order
        let sortedByResponseDesc = await memory.getHistory(sortedBy: { ($0.response ?? "") > ($1.response ?? "") })
        let responses = sortedByResponseDesc.map { $0.response ?? "" }
        
        XCTAssertEqual(responses, ["3", "2", "1"], "History should be sorted in descending order by response")
    }
}
