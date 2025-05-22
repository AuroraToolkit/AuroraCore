import XCTest
@testable import AuroraLLM

final class LLMParsingTests: XCTestCase {
    func testStripMarkdownJSON_noFence() {
        let input = "{\"key\":\"value\"}"
        XCTAssertEqual(input.stripMarkdownJSON(), input)
    }

    func testStripMarkdownJSON_withFence() {
        let input = "```json\n{\"key\":\"value\"}\n```"
        let expected = "{\"key\":\"value\"}"
        XCTAssertEqual(input.stripMarkdownJSON(), expected)
    }

    func testExtractThoughts_noThink_pureJSON() {
        let input = "{\"a\":1,\"b\":2}"
        let result = input.extractThoughtsAndStripJSON()
        XCTAssertTrue(result.thoughts.isEmpty)
        XCTAssertEqual(result.jsonBody, "{\"a\":1,\"b\":2}")
    }

    func testExtractThoughts_withThink_pureJSON() {
        let input = "<think> doing analysis </think>{\"a\":1}"
        let result = input.extractThoughtsAndStripJSON()
        XCTAssertEqual(result.thoughts, ["doing analysis"])
        XCTAssertEqual(result.jsonBody, "{\"a\":1}")
    }

    func testExtractThoughts_withFenceAndThink() {
        let input = "<think>first thought</think>\n```json\n{\"k\":3}\n```"
        let result = input.extractThoughtsAndStripJSON()
        XCTAssertEqual(result.thoughts, ["first thought"])
        XCTAssertEqual(result.jsonBody, "{\"k\":3}")
    }

    func testExtractThoughts_noJSON_onlyThought() {
        let input = "<think>just thinking</think>no json here"
        let result = input.extractThoughtsAndStripJSON()
        XCTAssertEqual(result.thoughts, ["just thinking"])
        XCTAssertEqual(result.jsonBody, "no json here")
    }
    
    func testExtractThoughts_multipleThinkBlocks() {
        let input = "<think>first thought</think><think>second thought</think>{\"x\":10}"
        let result = input.extractThoughtsAndStripJSON()
        XCTAssertEqual(result.thoughts, ["first thought", "second thought"])
        XCTAssertEqual(result.jsonBody, "{\"x\":10}")
    }

    func testExtractThoughts_realWorldScenario() {
        let input = """
        Note: Please analyze sentiment.
        <think>Planning analysis</think>
        <think>Gathering data</think>
        ```json
        { "sentiments": { "Happy test": "Positive", "Sad test": "Negative" } }
        ```
        """
        let result = input.extractThoughtsAndStripJSON()
        XCTAssertEqual(result.thoughts, ["Planning analysis", "Gathering data"])
        let expectedJSON = "{ \"sentiments\": { \"Happy test\": \"Positive\", \"Sad test\": \"Negative\" } }"
        XCTAssertEqual(result.jsonBody, expectedJSON)
    }

    func testExtractThoughts_onAnalyzeSentimentTaskOutput() {
        let input = """
        <think>Analyzing sentiments</think>
        ```json
        {
          "sentiments": {
            "Great!": "Positive",
            "Terrible.": "Negative"
          }
        }
        ```
        """
        let result = input.extractThoughtsAndStripJSON()
        XCTAssertEqual(result.thoughts, ["Analyzing sentiments"])
        let expectedJSON = """
        {
          "sentiments": {
            "Great!": "Positive",
            "Terrible.": "Negative"
          }
        }
        """
        XCTAssertEqual(result.jsonBody, expectedJSON)
    }
}