# AuroraCore

AuroraCore is the core library powering the Aurora AI assistant framework. This package is designed to manage the fundamental structures and workflows that support various AI-driven tasks, including context management, task workflows, and integrations with large language models (LLMs) such as OpenAI and Ollama. It is highly modular, allowing developers to extend its functionality and integrate with external services.

## Features

- **Context Management**: Handle and maintain conversation or task-specific context, including adding, retrieving, and summarizing items.
- **Task and Workflow Handling**: Built-in support for defining and managing tasks and workflows, including the ability to track task status and manage dependent workflows.
- **LLM Integration**: Seamless integration with various LLM services via an extendable `LLMManager`. Supports token management, trimming strategies, and fallback mechanisms.
- **Modular and Extendable**: AuroraCore is designed to be modular, allowing developers to plug in their own services, workflows, or task managers.

## Components

### 1. **ContextController**
The `ContextController` manages context data, including adding, updating, and summarizing items. It works closely with summarizers and handles context tokenization.

### 2. **Task and Workflow**
The `Task` and `Workflow` structs provide mechanisms to define tasks, monitor their progress, and execute complex workflows that are built from multiple tasks.

### 3. **LLMManager**
The `LLMManager` is responsible for managing connections to various language model services, handling requests, and managing token limits. It supports trimming strategies (start, middle, end) to fit within LLM token limits.

### 4. **ContextManager**
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

### Using Task and Workflow

```swift
import AuroraCore

let task = Task(id: UUID(), title: "Example Task")
var workflow = Workflow(id: UUID(), title: "Example Workflow", tasks: [task])

workflow.run()
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

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue.

## License

AuroraCore is released under the Apache 2.0 License.
