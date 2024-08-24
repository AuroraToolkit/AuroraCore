//
//  ContextStorage.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/20/24.
//

import Foundation

/**
 `ContextStorage` handles saving and loading `Context` objects to and from disk using JSON encoding.

 This class is responsible for encoding `Context` objects into JSON format and storing them in the document directory. 
 It also provides methods to retrieve and decode saved contexts from disk.
 */
public class ContextStorage {

    /// The file URL where the context will be saved.
    private let fileURL: URL

    /**
     Initializes a `ContextStorage` instance with a given filename.

     The filename is used to create a file in the app's document directory where the context will be stored.

     - Parameter filename: The name of the file (without extension) used for saving the context.
     - Returns: A `ContextStorage` instance, or `nil` if the document directory could not be found.
     */
    public init?(filename: String) {
        // Attempt to retrieve the document directory safely
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil // Fail the initialization if the directory is not found
        }
        self.fileURL = documentDirectory.appendingPathComponent("\(filename).json")
    }

    /**
     Saves the provided `Context` object to disk as a JSON file.

     - Parameter context: The `Context` object to be saved.
     - Throws: An error if encoding or writing the file fails.
     */
    public func saveContext(_ context: Context) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(context)
        try data.write(to: fileURL)
    }

    /**
     Loads and decodes a `Context` object from disk.

     This method reads the JSON file from the disk and decodes it into a `Context` object.

     - Returns: A `Context` object if the loading and decoding are successful.
     - Throws: An error if reading or decoding the file fails.
     */
    public func loadContext() throws -> Context {
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode(Context.self, from: data)
    }
}
