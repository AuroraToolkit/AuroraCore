//
// ModelTrainer.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/10/25.
//

import Foundation

#if os(macOS)
import CreateML
import CoreML

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
    let args = CommandLine.arguments
    guard args.count == 5 else {
      fputs("""
      Usage:
        ModelTrainer <csvPath> <textColumn> <labelColumn> <outputModelPath>
      """, stderr)
      exit(1)
    }

    let csvURL      = URL(fileURLWithPath: args[1])
    let textColumn  = args[2]
    let labelColumn = args[3]
    let outputURL   = URL(fileURLWithPath: args[4])

    do {
      try ModelTrainer.train(
        csvURL: csvURL,
        textColumn: textColumn,
        labelColumn: labelColumn,
        outputURL: outputURL
      )
    } catch {
      fputs("❌ Training failed: \(error)\n", stderr)
      exit(2)
    }
  }
}

struct ModelTrainer {
  static func train(
    csvURL: URL,
    textColumn: String,
    labelColumn: String,
    outputURL: URL
  ) throws {
    let data = try MLDataTable(contentsOf: csvURL)
    let classifier = try MLTextClassifier(
      trainingData: data,
      textColumn: textColumn,
      labelColumn: labelColumn
    )
    // Write the .mlmodel file
    try classifier.write(to: outputURL)
    print("✅ Trained model written to \(outputURL.path)")

    // Compile into a .mlmodelc bundle (this lives in a temp dir)
    let tempCompiledURL = try MLModel.compileModel(at: outputURL)

    // Now move it next to the .mlmodel as .mlmodelc
    let compiledDest = outputURL
      .deletingPathExtension()
      .appendingPathExtension("mlmodelc")

    // If there's an old bundle, remove it
    if FileManager.default.fileExists(atPath: compiledDest.path) {
      try FileManager.default.removeItem(at: compiledDest)
    }

    try FileManager.default.copyItem(at: tempCompiledURL, to: compiledDest)
    print("✅ Compiled model written to \(compiledDest.path)")
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
