# AuroraCore

AuroraCore is the foundational library within the AuroraToolkit—a suite of tools designed to simplify the integration of AI capabilities into your projects. This package provides robust support for AI-driven workflows, including context management, task orchestration, and seamless integrations with large language models (LLMs) from organizations such as Anthropic, OpenAI, and Ollama. Its modular architecture empowers developers to customize, extend, and integrate with external services effortlessly.

## Features

- **Context Management**: Handle and maintain conversation or task-specific context, including adding, retrieving, and summarizing items.
- **Task and Workflow Handling**: Built-in support for defining and managing tasks and workflows, supporting asynchronous task execution for handling complex, long-running tasks.
- **Declarative Workflow syntax**: Define workflows declaratively, similar to SwiftUI for UI.
- **LLM Integration**: Seamless integration with various LLM services via an extendable `LLMManager`. Supports token management, trimming strategies, domain-routing, and fallback mechanisms.
- **Domain-Specific Routing**: Route requests to the most appropriate LLM service based on predefined domains or fallback options, enabling modular and efficient service management.
- **Examples for Quick Start**: Includes ready-to-run examples demonstrating common patterns like domain-specific routing and fallback handling.
- **Modular and Extendable**: AuroraCore is designed to be modular, allowing developers to plug in their own services, workflows, or task managers.

## Major Components

### 1. **ContextController**
The `ContextController` manages context data, including adding, updating, and summarizing items. It works closely with summarizers and handles context tokenization.

### 2. **LLMManager**
The `LLMManager` is responsible for managing connections to various language model services, handling requests, and managing token limits. It supports trimming strategies (start, middle, end) to fit within LLM token limits.

### 3. **ContextManager**
`ContextManager` supervises multiple `ContextController` instances, allowing for the management of multiple contexts. It handles saving and loading contexts to disk, as well as setting the active context.

### 4. **Workflow**
The `Workflow` provide declarative mechanisms to define tasks and task groups, to execute complex workflows. It supports asynchronous task execution, making it suitable for workflows involving AI, network requests, and other asynchronous tasks.

## Installation

### Swift Package Manager

To integrate AuroraCore into your project using Swift Package Manager, add the following line to your `Package.swift` file:

```swift
.package(url: "https://github.com/AuroraToolkit/AuroraCore.git", from: "0.1.0")
```

Then add `AuroraCore` as a dependency to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["AuroraCore"]),
```

## Usage

### Setting up a Context

```swift
import AuroraCore

let contextController = ContextController(maxTokenLimit: 4096)
contextController.addItem(content: "This is a new item.")
let summary = contextController.summarizeContext()
```

### Using Workflows and Tasks

```swift
import AuroraCore

let workflow = Workflow(name: "Example Workflow", description: "This is a sample workflow") {
    Workflow.Task(name: "Task_1", description: "This is the first task.")
    Workflow.Task(name: "Task_2", description: "This is the second task.") { inputs in
        // Perform some task-specific logic
        return ["result": "Task 2 completed."]
    }
}

await workflow.start()

print("Workflow completed. Result: \(workflow.outputs["Task_2.result"] as? String)")
```

### LLM Integration

```swift
import AuroraCore

let llmManager = LLMManager()
llmManager.registerService(OllamaService(name: "Ollama"))

let request = LLMRequest(prompt: "Hello, World!")
llmManager.sendRequest(request) { response in
    print(response?.text ?? "No response")
}
```

### Domain-specific Routing with LLMManager

```swift
import AuroraCore

let manager = LLMManager()

// Configure the Domain Routing Service (Ollama)
let router = LLMDomainRouter(
    name: "Domain Router",
    service: OllamaService(),
    supportedDomains: ["sports", "movies", "books"]
)
manager.registerDomainRouter(router)

// Configure the Sports Service (Anthropic)
let sportsService = AnthropicService(
    name: "SportsService",
    apiKey: "your-anthropic-api-key",
    maxOutputTokens: 256,
    systemPrompt: """
You are a sports expert. Answer the following sports-related questions concisely and accurately.
"""
)
manager.registerService(sportsService, withRoutings: [.domain(["sports"])])

// Configure the Movies Service (OpenAI)
let moviesService = OpenAIService(
    name: "MoviesService",
    apiKey: "your-openai-api-key",
    maxOutputTokens: 256,
    systemPrompt: """
You are a movie critic. Answer the following movie-related questions concisely and accurately.
"""
)
manager.registerService(moviesService, withRoutings: [.domain(["movies"])])

// Configure the Books Service (Ollama)
let booksService = OllamaService(
    name: "BooksService",
    baseURL: "http://localhost:11434",
    maxOutputTokens: 256,
    systemPrompt: """
You are a literary expert. Answer the following books-related questions concisely and accurately.
"""
)
manager.registerService(booksService, withRoutings: [.domain(["books"])])

// Configure the Fallback Service (OpenAI)
let fallbackService = OpenAIService(
    name: "FallbackService",
    apiKey: "your-openai-api-key",
    maxOutputTokens: 512,
    systemPrompt: """
You are a helpful assistant. Answer any general questions accurately and concisely.
"""
)
manager.registerFallbackService(fallbackService)

// Example questions
let questions = [
    "Who won the Super Bowl in 2022?",  // Sports domain
    "What won Best Picture in 2021?",   // Movies domain
    "Who wrote The Great Gatsby?",      // Books domain
    "What is the capital of France?"    // General (fallback)
]

// Process each question
for question in questions {
    print("\nProcessing question: \(question)")

    let request = LLMRequest(messages: [LLMMessage(role: .user, content: question)])

    if let response = await manager.routeRequest(request) {
        print("Response from \(response.vendor ?? "Uknown"): \(response.text)")
    } else {
        print("No response received.")
    }
}
```

## Running Tests

AuroraCore includes tests for multiple language model services. The Ollama tests will always run, as they do not require any API keys. For testing OpenAI or Anthropic services, you will need to manually provide your API keys.

### Adding API Keys for OpenAI and Anthropic:

Some test and example files use OpenAI or Anthropic services and need API keys to function correctly. To use these services, add the following keys to the `AuroraCore` and `Examples` schemes. Make sure these schemes are not shared, and take extra precaution to avoid committing API keys into the repository.

- For Anthropic, add the environment variable `ANTHROPIC_API_KEY` with a valid test API key.
- For OpenAI, add the environment variable `OPENAI_API_KEY` with a valid test API key.
- Ollama does not require API keys, but does require the Ollama service to be running at the default service URL, `http://localhost:11434`.

### Important:
- **Never commit your API keys to the repository**. The tests are designed to run with Ollama by default, and you can enable additional tests for OpenAI and Anthropic by manually adding your keys for local testing.
- Be sure to remove or replace your keys with empty strings before committing any changes.

With this setup, you can run the tests on multiple LLMs and ensure your sensitive keys are not inadvertently shared.

## Future Ideas

- **On-device LLM support**: Integrate with on-device language models to enable fast, private, and offline AI capabilities.
- **Google LLM support**: Support Gemini and future Google-built language models.
- **Multimodal LLM support**: Enable multimodal LLMs for use cases beyond plain text.
- **Advanced Workflow features**: Include dynamic task execution, prebuilt workflow templates for common AI tasks (e.g., summarization, Q&A, data extraction) to jumpstart development.
- **Time-based triggers**: Automate workflows to execute at scheduled intervals or in response to real-world events for monitoring and alerting systems.

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue. For more details on how to contribute, please refer to the [CONTRIBUTING.md](CONTRIBUTING.md) file.

## Code of Conduct

We expect all participants to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md) to ensure a welcoming and inclusive environment for everyone.

## License

AuroraCore is released under the [Apache 2.0 License](LICENSE).

## Contact

For any inquiries or feedback, please reach out to us at [aurora.toolkit@gmail.com](mailto:aurora.toolkit@gmail.com).
