//
// ModelTrainer.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/10/25.
//

import Foundation

#if os(macOS)
    import CoreML
    import CreateML

    /**
        ModelTrainer is a command-line tool that trains a Core ML text classifier
        using a CSV file. It takes the path to the CSV file, the name of the text
        column, the name of the label column, and the output path for the trained
        model as command-line arguments.

        The tool uses CreateML to perform the training and outputs the trained
        model as a .mlmodel file. It also compiles the model into a .mlmodelc.

        Usage:
            ModelTrainer <csvPath> <textColumn> <labelColumn> <outputModelPath>

        Example:
            `swift run ModelTrainer data.csv text_column label_column model.mlmodel`
     */
    @main
    struct ModelTrainerCLI {
        static func main() {
            let rawArgs = CommandLine.arguments.dropFirst() // skip executable name

            // Check for compile-only flag
            let compileOnly = rawArgs.contains("--compile-only") || rawArgs.contains("-c")

            // Remove the flag from the list so positional args line up
            let args = rawArgs.filter { $0 != "--compile-only" && $0 != "-c" }

            guard args.count == 4 else {
                fputs("""
                Usage:
                  ModelTrainer [--compile-only|-c] <csvPath> <textColumn> <labelColumn> <outputModelPath>
                """, stderr)
                exit(1)
            }

            let csvURL = URL(fileURLWithPath: args[0])
            let textColumn = args[1]
            let labelColumn = args[2]
            let outputURL = URL(fileURLWithPath: args[3])

            do {
                try ModelTrainer.train(
                    csvURL: csvURL,
                    textColumn: textColumn,
                    labelColumn: labelColumn,
                    outputURL: outputURL,
                    compileOnly: compileOnly
                )
            } catch {
                fputs("❌ Training failed: \(error)\n", stderr)
                exit(2)
            }
        }
    }

    enum ModelTrainer {
        /// Trains a text classifier and optionally only writes out the compiled .mlmodelc.
        static func train(
            csvURL: URL,
            textColumn: String,
            labelColumn: String,
            outputURL: URL,
            compileOnly: Bool = false
        ) throws {
            let data = try MLDataTable(contentsOf: csvURL)
            let classifier = try MLTextClassifier(
                trainingData: data,
                textColumn: textColumn,
                labelColumn: labelColumn
            )

            // Decide where to write the raw .mlmodel
            let sourceModelURL: URL
            if compileOnly {
                // Write to a temp directory
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                sourceModelURL = tempDir.appendingPathComponent(outputURL.lastPathComponent)
            } else {
                sourceModelURL = outputURL
            }

            // Always write the uncompiled model to sourceModelURL
            try classifier.write(to: sourceModelURL)
            if !compileOnly {
                print("✅ Trained model written to \(sourceModelURL.path)")
            }

            // Compile into a .mlmodelc
            let tempCompiledURL = try MLModel.compileModel(at: sourceModelURL)
            let compiledDest = outputURL
                .deletingPathExtension()
                .appendingPathExtension("mlmodelc")

            // Remove any existing compiled bundle
            if FileManager.default.fileExists(atPath: compiledDest.path) {
                try FileManager.default.removeItem(at: compiledDest)
            }

            try FileManager.default.copyItem(at: tempCompiledURL, to: compiledDest)
            print("✅ Compiled model written to \(compiledDest.path)")

            // Clean up temp if needed
            if compileOnly {
                try FileManager.default.removeItem(at: sourceModelURL.deletingLastPathComponent())
            }
        }
    }
#else

    @main
    struct ModelTrainerCLI {
        static func main() {
            print("⚠️ ModelTrainer only runs on macOS")
        }
    }

#endif
