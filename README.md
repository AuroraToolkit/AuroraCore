# AuroraCore

AuroraCore is the core library powering the Aurora AI assistant framework. This package is designed to manage the fundamental structures and workflows that support various AI-driven tasks, including context management, task workflows, and integrations with large language models (LLMs) such as OpenAI and Ollama. It is highly modular, allowing developers to extend its functionality and integrate with external services.

## Features

- **Context Management**: Handle and maintain conversation or task-specific context, including adding, retrieving, and summarizing items.
- **Task and Workflow Handling**: Built-in support for defining and managing tasks and workflows, including the ability to track task status and manage dependent workflows. Now supports asynchronous task execution for handling complex, long-running tasks.
- **LLM Integration**: Seamless integration with various LLM services via an extendable `LLMManager`. Supports token management, trimming strategies, and fallback mechanisms.
- **Modular and Extendable**: AuroraCore is designed to be modular, allowing developers to plug in their own services, workflows, or task managers.

## Components

### 1. **ContextController**
The `ContextController` manages context data, including adding, updating, and summarizing items. It works closely with summarizers and handles context tokenization.

### 2. **WorkflowTask and Workflow**
The `WorkflowTask` and `Workflow` classes provide mechanisms to define tasks, monitor their progress, and execute complex workflows that are built from multiple tasks.

### 3. **WorkflowManager**
The `WorkflowManager` is responsible for managing and executing workflows. It coordinates task execution, handles task failures, and manages workflow states such as `inProgress`, `stopped`, `completed`, and `failed`. It supports asynchronous execution, making it suitable for workflows involving AI, network requests, and other asynchronous tasks.

### 4. **LLMManager**
The `LLMManager` is responsible for managing connections to various language model services, handling requests, and managing token limits. It supports trimming strategies (start, middle, end) to fit within LLM token limits.

### 5. **ContextManager**
`ContextManager` supervises multiple `ContextController` instances, allowing for the management of multiple contexts. It handles saving and loading contexts to disk, as well as setting the active context.

## Installation

### Swift Package Manager

To integrate AuroraCore into your project using Swift Package Manager, add the following line to your `Package.swift` file:

```swift
.package(url: "https://github.com/yourusername/AuroraCore.git", from: "1.0.0")
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

### Using WorkflowTask and Workflow

```swift
import AuroraCore

let task = WorkflowTask(name: "Example Task", description: "This is a sample task.")
var workflow = Workflow(name: "Example Workflow", description: "This is a sample workflow", tasks: [task])

let workflowManager = WorkflowManager(workflow: workflow)

// Starting the workflow
Task {
    await workflowManager.start()
}
```

### LLM Integration

```swift
import AuroraCore

let llmManager = LLMManager()
llmManager.registerService(MockLLMService(), withName: "MockService")

let request = LLMRequest(prompt: "Hello, World!")
llmManager.sendRequest(request) { response in
    print(response?.text ?? "No response")
}
```

## Running Tests

AuroraCore includes tests for multiple language model services. The Ollama tests will always run, as they do not require any API keys. For testing OpenAI or Anthropic services, you will need to manually provide your API keys.

### Adding API Keys for OpenAI and Anthropic:

In the test files that involve OpenAI or Anthropic services, there are placeholders where you can insert your API keys.

1. Open the `LLMServiceTests.swift` file.
2. Locate the following lines near the top of the file:
    ```swift
    private let openAIAPIKey: String? = "" // Insert your OpenAI API key here
    private let anthropicAPIKey: String? = "" // Insert your Anthropic API key here
    ```
3. Add your keys between the quotation marks (`""`) to enable the tests for those services.

### Important:
- **Do not commit your API keys to the repository**. The tests are designed to run with Ollama by default, and you can enable additional tests for OpenAI and Anthropic by manually adding your keys for local testing.
- Be sure to remove or replace your keys with empty strings before committing any changes.

With this setup, you can run the tests without relying on environment variables, and ensure your sensitive keys are not inadvertently shared.

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue.

## License

AuroraCore is released under the Apache 2.0 License.
