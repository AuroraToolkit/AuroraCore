//
//  main.swift

import AuroraCore
import Foundation

// swiftlint:disable orphaned_doc_comment

/**
 These examples use a mix of Anthropic, OpenAI, Google, and Ollama models.

 To run these examples, you must have the following environment variables set:
    - OPENAI_API_KEY: Your OpenAI API key
    - ANTHROPIC_API_KEY: Your Anthropic API key
    - GOOGLE_API_KEY: Your Google API key

    You can set these environment variables in the `Examples` scheme or by using the following commands:
    ```
    export OPENAI_API_KEY="your-openai-api-key"
    export ANTHROPIC_API_KEY="your-anthropic-api-key"
    export GOOGLE_API_KEY="your-google-api-key"
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
    swift run AuroraExamples
    ```
 */

// Uncomment the following line to disable debug logs
// CustomLogger.shared.toggleDebugLogs(false)

print("Aurora Core Examples\n")
print("--------------------\n")

print("BasicRequest Example:\n")
await BasicRequestExample().execute()

print("--------------------\n")

print("StreamingRequest Example:\n")
await StreamingRequestExample().execute()

print("--------------------\n")

print("LLM Routing Example:\n")
await LLMRoutingExample().execute()

print("--------------------\n")

print("Domain Routing Example:\n")
await DomainRoutingExample().execute()

print("--------------------\n")

print("Dual Domain Routing Example:\n")
await DualDomainRoutingExample().execute()

print("--------------------\n")

print("Siri Style Domain Routing Example:\n")
await SiriStyleDomainRoutingExample().execute()

print("--------------------\n")

print("Logic Domain Routing Example:\n")
await LogicDomainRouterExample().execute()

print("--------------------\n")

print("TV Script Workflow Example:\n")
await TVScriptWorkflowExample().execute()

print("--------------------\n")

print("Translate Text Workflow Example:\n")
await LeMondeTranslationWorkflow().execute()

print("--------------------\n")

print("App Store Customer Feedback Analysis Workflow Example:\n")
await CustomerFeedbackAnalysisWorkflow().execute()

print("--------------------\n")

print("Temperature Monitor Workflow Example:\n")
await TemperatureMonitorWorkflow().execute()

print("--------------------\n")

print("Blog Post Categorization Workflow Example:\n")
await BlogCategoryWorkflowExample().execute()

print("--------------------\n")

print("Support Ticket Analysis Workflow Example:\n")
await SupportTicketWorkflowExample().execute(on: "My account is locked after too many login attempts.")

print("--------------------\n")

print("Triage Github Issues Workflow Example:\n")
await IssueTriageWorkflowExample().execute(on: "App crashes with error E401 when I press Save")

// swiftlint:enable orphaned_doc_comment
