//
//  main.swift

import Foundation
import AuroraCore

/**
 These examples use a mix of Anthropic, OpenAI, and Ollama models.

 To run these examples, you must have the following environment variables set:
    - OPENAI_API_KEY: Your OpenAI API key
    - ANTHROPIC_API_KEY: Your Anthropic API key

    You can set these environment variables using the following commands:
    ```
    export OPENAI_API_KEY="your-openai-api-key"
    export ANTHROPIC_API_KEY="your-anthropic-api-key"
    ```

    Additionally, you must have the Ollama service running locally on port 11434.

    These examples demonstrate how to:
    - Make requests to different LLM services
    - Stream requests to a service
    - Route requests between services based on token limits
    - Route requests between services based on the domain

    Each example is self-contained and demonstrates a specific feature of the Aurora Core framework.

 To run these examples, execute the following command in the terminal from the root directory of the project:
    ```
    swift run Examples
    ```
 */

//print("Aurora Core Examples\n")
//print("--------------------\n")
//
//print("BasicRequest Example:\n")
//await BasicRequestExample().execute()
//
//print("--------------------\n")
//
//print("StreamingRequest Example:\n")
//await StreamingRequestExample().execute()
//
//print("--------------------\n")
//
//print("LLM Routing Example:\n")
//await LLMRoutingExample().execute()
//
//print("--------------------\n")
//
//print("Domain Routing Example:\n")
//await DomainRoutingExample().execute()

print("--------------------\n")

print("Article Summarization Example:\n")
await ArticleSummariesWorkflowExample().execute()
