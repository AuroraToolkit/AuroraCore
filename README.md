# AuroraCore

AuroraCore is the foundational library within the **AuroraToolkit**—a suite of tools designed to simplify the integration of AI capabilities into your projects. This package offers robust support for AI-driven workflows, including task orchestration, workflow management, on-device ML services, and seamless integration with large language models (LLMs) like Anthropic Claude, Google Gemini, OpenAI ChatGPT, and open-source Ollama models. Its modular architecture empowers developers to customize, extend, and integrate with external services effortlessly.

The AuroraToolkit core package is organized into several modules to enhance flexibility and maintainability:

- **AuroraCore**: The foundational library for workflow orchestration, utilities, and declarative task management.
- **AuroraLLM**: A dedicated package for integrating large language models (LLMs) such as Anthropic, Google, OpenAI, and Ollama.
- **AuroraML**: On-device ML services (classification, intent extraction, tagging, embedding, semantic search) and corresponding Workflow tasks.  
- **AuroraTaskLibrary**: A growing collection of prebuilt, reusable tasks designed to accelerate development.
- **AuroraExamples**: Practical examples demonstrating how to leverage the toolkit for real-world scenarios.

Whether you're building sophisticated AI-powered applications or integrating modular components into your workflows, AuroraCore provides the tools and flexibility to bring your ideas to life.


## Features

- **Modular Design**: Organized into distinct modules for core workflow management, LLM integration, and reusable tasks, providing flexibility and maintainability.
- **Declarative Workflows**: Define workflows and subflows declaratively, similar to SwiftUI, enabling clear and concise task orchestration.
- **Dynamic Workflows**: Use logic and triggers to create dynamic workflows that adapt to changing conditions, scheduled intervals, or user input.
- **Reusable Tasks**: A library of prebuilt tasks for common development needs, from URL fetching to context summarization, accelerates your workflow setup.
- **LLM Integration**: Effortless integration with major LLM providers like Anthropic, Google, OpenAI, and Ollama, with support for token management, domain-specific routing, and fallback strategies.
- **On-device ML Tasks**: Integrate on-device ML-based tasks for classification, intent extraction, tagging, embedding, and semantic search, enhancing privacy and performance.
- **Hybrid LLM + On-Device Pipelines**: Combine on-device ML tasks with cloud or local LLMs for advanced end-to-end pipelines.
- **Domain-Specific Routing**: Automatically route requests to the most appropriate LLM service based on predefined domains, optimizing task execution and resource allocation.
- **Customizable and Extendable**: Easily add custom tasks, workflows, or LLM integrations to suit your project needs.
- **Practical Examples**: Includes real-world examples to help developers get started quickly with common use cases and advanced patterns.
- **Asynchronous Execution**: Built-in support for asynchronous task execution, handling complex and long-running tasks seamlessly.
- **On-device Domain Routing**: Use CoreML models to perform domain classification directly on-device with `CoreMLDomainRouter`.
- **Hybrid Routing Logic**: Combine predictions from two domain routers with `DualDomainRouter` to resolve ambiguous or conflicting cases using confidence thresholds or custom resolution logic.
- **Logic-Based Domain Routing**: Use `LogicDomainRouter` for custom domain routing based on user-defined logic, allowing for flexible and dynamic routing strategies.


## Modules

### **1. AuroraCore**
The foundational library providing the core framework for workflows, task orchestration, and utility functions. 

#### Key Features:
- **Workflow**: A declarative system for defining and executing tasks and task groups. Workflows support asynchronous and dynamic task execution, making them ideal for chaining AI-driven operations, network calls, or any other asynchronous logic.
- **Utilities**: A collection of helper functions, including token handling, secure storage, debugging, and file management.

### **2. AuroraLLM**
A dedicated package for managing large language models (LLMs) and facilitating AI-driven workflows. It includes multi-model management, domain routing, and token handling. Provides support for various LLM vendors, including Anthropic, Google, OpenAI, and Ollama.

Includes native support for:
- `CoreMLDomainRouter`: On-device domain classification using compiled Core ML models (`.mlmodelc`).
- `DualDomainRouter`: Combines a primary and contrastive router with customizable resolution strategies for maximum accuracy.


#### Key Features:
- **LLMManager**: Centralized management of multiple LLMs, with support for routing requests to appropriate models based on predefined rules.
- **Domain Routing**: Automatically routes prompts to the best-suited LLM for a specific domain (e.g., sports, movies, books).
- **Summarization Support**: Built-in summarizers for extracting key information from text, tailored to work with LLM outputs.

### **3. AuroraML**
On-device ML services and Workflow tasks, powered by Apple’s Natural Language & Create ML frameworks.

### **4. AuroraTaskLibrary**
A collection of prebuilt tasks designed to jumpstart development and integrate seamlessly with workflows. These tasks cover common AI and utility-based operations.

#### Notable Tasks:
- **JSONParsingTask**: Parses JSON data and extracts values based on key paths.
- **RSSParsingTask**: Parses RSS feeds and extracts articles.
- **TrimmingTask**: Cleans and trims text input for better processing.
- **FetchURLTask**: Fetches data from a given URL.
- **AnalyzeSentimentTask** (LLM): Analyzes the sentiment of the input text.
- **DetectLanguagesTask** (LLM): Identifies the language of the input text.
- **GenerateKeywordsTask** (LLM): Extracts keywords from the input text.
- **SummarizeContextTask** (LLM): Summarizes text or contextual data using registered LLMs.

### **5. AuroraExamples**
A separate package showcasing real-world implementations of workflows, LLM integrations, and tasks. Examples demonstrate:
- How to use the LLMManager for multi-model management
- How to set up declarative workflows
- How to use tasks to perform common operations
- How to use domain-specific and contrastive routing
- How to run Core ML-based classification locally on-device



## Installation

### Swift Package Manager

To integrate AuroraCore into your project using Swift Package Manager, add the following line to your `Package.swift` file:

```swift
.package(url: "https://github.com/AuroraToolkit/AuroraCore.git", from: "0.9.2")
```

Then add the desired modules as dependencies to your target. For example:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "AuroraCore", package: "AuroraToolkit"),
        .product(name: "AuroraLLM", package: "AuroraToolkit"),
        .product(name: "AuroraML", package: "AuroraToolkit"),
        .product(name: "AuroraTaskLibrary", package: "AuroraToolkit")
    ]
),
```

You can include only the modules you need in your project to keep it lightweight and focused.


## Usage

### Setting up a Context

```swift
import AuroraLLM

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
import AuroraLLM

let llmManager = LLMManager()
llmManager.registerService(OllamaService(name: "Ollama"))

let request = LLMRequest(prompt: "Hello, World!")
llmManager.sendRequest(request) { response in
    print(response?.text ?? "No response")
}
```

### Domain Routing Examples

#### Siri-Style On-Device Routing (CoreMLDomainRouter)
Use a `.mlmodelc` classifier to predict whether a prompt should be handled on-device, off-device, or marked as "unsure." Perfect for Siri-style domain separation.

```swift
let router = CoreMLDomainRouter(
    name: "PrimaryRouter",
    modelURL: modelPath(for: "SiriStyleTextClassifier.mlmodelc"),
    supportedDomains: ["private", "public", "unsure"]
)
```

#### Contrastive Domain Resolution (DualDomainRouter)
Use both a primary and secondary router, with optional thresholds and fallback logic:

```swift
let router = DualDomainRouter(
    name: "SiriStyleRouter",
    primary: router1,
    secondary: router2,
    supportedDomains: ["private", "public", "unsure"],
    confidenceThreshold: 0.25,
    fallbackDomain: "unsure",
    fallbackConfidenceThreshold: 0.30,
    resolveConflict: { primary, secondary in
        if let p = primary, p.confidence >= 0.90 { return p.label }
        if let s = secondary, s.confidence >= 0.90 { return s.label }
        return "unsure"
    }
)
```

#### Logic-Based Domain Routing (LogicDomainRouter)
Use a custom logic-based router to determine the domain based on privacy rules:

```swift
    let privacyRouter = LogicDomainRouter(
        name: "Privacy Gate",
        supportedDomains: ["private","public"],
        rules: [
            .regex(name:"Credit Card",
                   pattern:#"\b(?:\d[ -]*?){13,16}\b"#,
                   domain:"private", priority:100),
            .regex(name:"US Phone",
                   pattern:#"\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b"#,
                   domain:"private", priority:100),
            .regex(name: "Email",
                   pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
                   domain: "private",
                   priority: 100),
            .regex(name: "SSN",
                   pattern: #"\b\d{3}-\d{2}-\d{4}\b"#,
                   domain: "private",
                   priority: 100)
        ],
        defaultDomain: "public",
        evaluationStrategy: .highestPriority
    )
```


#### LLM-Based Routing (LLMDomainRouter)

```swift
import AuroraLLM

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

AuroraCore includes tests for multiple language model services. The Ollama tests will always run, as they do not require any API keys. For testing Anthropic, Google, or OpenAI services, you will need to manually provide your API keys.

### .env example

To simplify adding environment variables for API keys, copy the `.env.example` file to `.env` and fill in your keys:

```bash
cp .env.example .env
```

Then edit `.env` with your API keys.

### Adding API Keys for Anthropic, Google, and OpenAI:

Some test and example files use OpenAI or Anthropic services and need API keys to function correctly. To use these services, add the following keys to the `AuroraToolkit-Package` and `AuroraExamples` schemes. Make sure these schemes are not shared, and take extra precaution to avoid committing API keys into the repository.

- For Anthropic, add the environment variable `ANTHROPIC_API_KEY` with a valid test API key.
- For Google, add the environment variable `GOOGLE_API_KEY` with a valid test API key.
- For OpenAI, add the environment variable `OPENAI_API_KEY` with a valid test API key.
- Ollama does not require API keys, but does require the Ollama service to be running at the default service URL, `http://localhost:11434`.

### Important:
- **Never commit your API keys to the repository**. The tests are designed to run with Ollama by default, and you can enable additional tests for Anthropic, Google, and OpenAI by manually adding your keys for local testing.
- Be sure to remove or replace your keys with empty strings before committing any changes.

With this setup, you can run the tests on multiple LLMs and ensure your sensitive keys are not inadvertently shared.

## Future Ideas

- **On-device LLM support**: Integrate with on-device language models to enable fast, private, and offline AI capabilities.
- **Multimodal LLM support**: Enable multimodal LLMs for use cases beyond plain text.
- **Advanced Workflow features**: Include prebuilt workflow templates for common AI tasks (e.g., summarization, Q&A, data extraction) to jumpstart development.

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue. For more details on how to contribute, please refer to the [CONTRIBUTING.md](CONTRIBUTING.md) file.

## Code of Conduct

We expect all participants to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md) to ensure a welcoming and inclusive environment for everyone.

## License

AuroraCore is released under the [Apache 2.0 License](LICENSE).

## Contact

For any inquiries or feedback, please reach out to us at [aurora.toolkit@gmail.com](mailto:aurora.toolkit@gmail.com).
