//
//  ContextManager.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/21/24.
//

import Foundation

/**
 `ContextManager` is responsible for managing multiple `ContextController` instances. It allows adding, removing, switching between contexts, and saving/restoring contexts from disk.
 */
public class ContextManager {

    /// A dictionary mapping UUIDs to their respective `ContextController` instances.
    internal var contextControllers: [UUID: ContextController] = [:]

    /// The ID of the currently active context.
    internal var activeContextID: UUID?

    /**
     Adds a new context to the manager and returns the unique identifier of the new context.

     - Parameters:
        - context: An optional `Context` object. If none is provided, a new one will be created automatically.
        - maxTokenLimit: The maximum token limit for the context's `TokenManager`, defaulting to 4096.
        - summarizer: An optional `Summarizer` instance to handle text summarization. If none is provided, a default summarizer will be created.
     - Returns: The unique identifier (`UUID`) for the newly created `ContextController`.
     */
    public func addNewContext(_ context: Context? = nil, maxTokenLimit: Int = 4096, summarizer: Summarizer? = nil) -> UUID {
        let contextController = ContextController(context: context, maxTokenLimit: maxTokenLimit, summarizer: summarizer)
        contextControllers[contextController.id] = contextController
        if activeContextID == nil {
            activeContextID = contextController.id
        }
        return contextController.id
    }

    /**
     Removes a `ContextController` by its ID.

     - Parameter contextID: The UUID of the context to be removed.
     */
    public func removeContext(withID contextID: UUID) {
        contextControllers.removeValue(forKey: contextID)

        // Update the active context if the removed context was the active one
        if activeContextID == contextID {
            activeContextID = contextControllers.keys.first
        }
    }

    /**
     Sets the active context by its ID.

     - Parameter contextID: The UUID of the context to be set as active.
     */
    public func setActiveContext(withID contextID: UUID) {
        guard contextControllers[contextID] != nil else {
            return
        }
        activeContextID = contextID
    }

    /**
     Retrieves the currently active `ContextController`.

     - Returns: The active `ContextController`, or `nil` if there is no active context.
     */
    public func getActiveContextController() -> ContextController? {
        guard let activeContextID = activeContextID else {
            return nil
        }
        return contextControllers[activeContextID]
    }

    /**
     Retrieves a `ContextController` for a given context ID.

     - Parameter contextID: The UUID of the context to be retrieved.
     - Returns: The `ContextController` associated with the given context ID, or `nil` if no such context exists.
     */
    public func getContextController(for contextID: UUID) -> ContextController? {
        return contextControllers[contextID]
    }

    /**
     Retrieves all managed `ContextController` instances.

     - Returns: An array of all `ContextController` instances managed by this `ContextManager`.
     */
    public func getAllContextControllers() -> [ContextController] {
        return Array(contextControllers.values)
    }

    /**
     Summarizes older context items across all managed `ContextController` instances.

     This method will invoke the `summarizeOlderContext()` function for each `ContextController` stored in the manager.
     */
    public func summarizeOlderContexts() {
        for (_, controller) in contextControllers {
            controller.summarizeOlderContext()
        }
    }

    /**
     Saves all managed contexts to disk.

     Each context is saved as a separate file using its UUID in the filename.

     - Throws: Any errors encountered during saving.
     */
    public func saveAllContexts() throws {
        for (contextID, contextController) in contextControllers {
            let storage = ContextStorage(filename: "context_\(contextID.uuidString)")
            try storage?.saveContext(contextController.getContext())
        }
    }

    /**
     Loads all contexts from disk and restores them as `ContextController` instances.

     This function scans the document directory for saved contexts and restores them into the manager.

     - Throws: Any errors encountered during loading.
     */
    public func loadAllContexts() throws {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "Aurora", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to find document directory"])
        }

        // Filter the files in the document directory to those that match the "context_" prefix.
        let contextFiles = try fileManager.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("context_") }

        for file in contextFiles {
            let storage = ContextStorage(filename: file.lastPathComponent.replacingOccurrences(of: ".json", with: ""))
            let loadedContext = try storage?.loadContext()

            let contextController = ContextController(context: loadedContext, maxTokenLimit: 4096)
            let contextID = UUID(uuidString: file.lastPathComponent.replacingOccurrences(of: "context_", with: "").replacingOccurrences(of: ".json", with: ""))!
            contextControllers[contextID] = contextController

            // Set the first loaded context as active if no context is active.
            if activeContextID == nil {
                activeContextID = contextID
            }
        }
    }
}
