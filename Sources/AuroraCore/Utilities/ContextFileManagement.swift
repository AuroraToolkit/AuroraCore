//
//  ContextFileManagement.swift
//
//
//  Created by Dan Murrell Jr on 9/7/24.
//

import Foundation

public extension FileManager {
    /// Helper function to create the `contexts` directory in the documents folder if it doesn't exist.
    func createContextsDirectory() throws -> URL {
        guard let documentDirectory = urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "FileManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Document directory not found"])
        }
        let contextsDirectory = documentDirectory.appendingPathComponent("aurora/contexts")

        if !fileExists(atPath: contextsDirectory.path) {
            try createDirectory(at: contextsDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        return contextsDirectory
    }
}
