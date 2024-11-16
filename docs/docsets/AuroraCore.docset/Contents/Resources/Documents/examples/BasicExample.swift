// BasicExample.swift
import AuroraCore

// Create a context controller
let contextController = ContextController(maxTokenLimit: 4096)

// Add an item to the context
contextController.addItem(content: "This is a new item.")

// Summarize the context
let summary = contextController.summarizeContext()
print("Context Summary: \(summary)")
