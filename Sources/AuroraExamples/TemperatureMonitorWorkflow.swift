//
//  TemperatureMonitorWorkflow.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 2/24/25.
//

import Foundation
import AuroraCore
import AuroraLLM
import AuroraTaskLibrary

/**
 Example workflow demonstrating a conditional subflow for temperature monitoring.

 The workflow simulates reading a temperature value, then conditionally executes a subflow:
 - If the temperature is above a safe threshold, an alert subflow is run.
 - Otherwise, a normal log subflow is run.

 A trigger component re-inserts the logic check periodically, allowing the workflow to continuously monitor the temperature.
 This version limits the trigger to fire a maximum of 10 times with a 6‑second delay between checks.
 Finally, a task analyzes the temperature history, computing average, median, normal count, and abnormal count.
 */
struct TemperatureMonitorWorkflow {
    // A simulated safe temperature threshold.
    let safeThreshold: Double = 75.0

    // Counters to track high and normal temperature occurrences.
    var highTempCounter = Counter()
    var normalTempCount = Counter()

    // A helper function to simulate reading the current temperature.
    func getCurrentTemperature() -> Double {
        // For demo purposes, return a random temperature between 60 and 90.
        return Double.random(in: 60...90)
    }

    // A simple class to hold temperature history.
    final class TempHistory {
        var history: [Double] = []
        func addTemperature(_ temp: Double) {
            history.append(temp)
        }
    }

    // MARK: - Subflow Builders

    func highTempSubflow(for currentTemp: Double) -> Workflow.Component {
        highTempCounter.count += 1
        return Workflow.Subflow(name: "HighTempAlert", description: "Alert subflow for high temperature") {
            Workflow.Task(name: "SendAlert", description: "Send an alert for high temperature") { _ in
                print("Alert: Temperature (\(currentTemp)) is above safe threshold!")
                return ["\(highTempCounter.count)": "Temperature \(currentTemp) is too high!"]
            }
        }.toComponent()
    }

    func normalLogSubflow(for currentTemp: Double) -> Workflow.Component {
        normalTempCount.count += 1
        return Workflow.Subflow(name: "NormalLog", description: "Logging subflow for normal temperature") {
            Workflow.Task(name: "LogTemperature", description: "Log normal temperature") { _ in
                print("Log: Temperature (\(currentTemp)) is normal.")
                return ["\(normalTempCount.count)": "Temperature \(currentTemp) is normal."]
            }
        }.toComponent()
    }

    // MARK: - Counter Factory

    final class Counter {
        var count: Int
        init(count: Int = 0) {
            self.count = count
        }
    }

    // A helper function that returns a new periodic trigger, up to 10 times.
    func makePeriodicTrigger(counter: Counter, history: TempHistory) -> Workflow.Component {
        return Workflow.Trigger(name: "PeriodicRecheck-\(counter.count)", description: "Recheck temperature every 6 seconds (max 10 times)") {
            print("Evaluating Workflow.Trigger: PeriodicRecheck")
            try await Task.sleep(nanoseconds: 6_000_000_000) // 6 seconds delay
            counter.count += 1
            print("Trigger fired: \(counter.count) time(s)")
            if counter.count < 10 {
                let currentTemp = self.getCurrentTemperature()
                history.addTemperature(currentTemp)
                let logicComponent = Workflow.Logic(name: "CheckTemperature", description: "Re-evaluate temperature") {
                    print("Re-evaluating temperature: \(currentTemp)")
                    if currentTemp > self.safeThreshold {
                        return [self.highTempSubflow(for: currentTemp)]
                    } else {
                        return [self.normalLogSubflow(for: currentTemp)]
                    }
                }
                // Return both the new logic component and a new trigger (fresh instance).
                return [logicComponent.toComponent(), self.makePeriodicTrigger(counter: counter, history: history)]
            } else {
                return []
            }
        }.toComponent()
    }

    func execute() async {
        // Create a counter instance to track trigger firings.
        let counter = Counter()

        // Create a history instance to store temperature readings.
        let history = TempHistory()

        // Workflow initialization
        var workflow = Workflow(
            name: "Temperature Monitor Workflow",
            description: "Monitors temperature and triggers alerts if it exceeds a safe threshold."
        ) {
            // Step 1: Read the current temperature.
            Workflow.Task(name: "ReadTemperature", description: "Simulate reading temperature") { _ in
                let temperature = self.getCurrentTemperature()
                history.addTemperature(temperature)
                print("Current temperature: \(temperature)")
                return ["initial_temperature": temperature]
            }

            // Step 2: Evaluate the temperature and choose a subflow.
            Workflow.Logic(name: "CheckTemperature", description: "Decide which subflow to run based on temperature") {
                let currentTemp = self.getCurrentTemperature()
                history.addTemperature(currentTemp)
                print("Evaluating temperature: \(currentTemp)")
                if currentTemp > self.safeThreshold {
                    return [highTempSubflow(for: currentTemp)]
                } else {
                    return [normalLogSubflow(for: currentTemp)]
                }
            }.toComponent()

            // Step 3: Insert the periodic trigger.
            self.makePeriodicTrigger(counter: counter, history: history)

            // Step 4: Final task to analyze temperature history.
            Workflow.Task(name: "AnalyzeTempHistory", description: "Analyze temperature history") { _ in
                let readings = history.history
                guard !readings.isEmpty else {
                    return ["analysis": "No temperature data available."]
                }
                // Compute average.
                let sum = readings.reduce(0, +)
                let average = sum / Double(readings.count)
                // Compute median.
                let sorted = readings.sorted()
                let median: Double = sorted.count % 2 == 1 ?
                    sorted[sorted.count/2] :
                    (sorted[sorted.count/2 - 1] + sorted[sorted.count/2]) / 2
                // Count normal vs abnormal.
                let normalCount = readings.filter { $0 <= self.safeThreshold }.count
                let highCount = readings.filter { $0 > self.safeThreshold }.count
                return [
                    "average": average,
                    "median": median,
                    "normalCount": normalCount,
                    "highCount": highCount
                ]
            }
        }

        print("Executing \(workflow.name)...")
        print(workflow.description)

        // Execute the workflow.
        await workflow.start()

        // Print the workflow outputs.
        print("\nWorkflow Outputs:")
        print(workflow.outputs)

        print("\n-------\n")

        print("Temperature insights:")
        // Print the normal and abnormal temperature counts.
        if let normalCount = workflow.outputs["AnalyzeTempHistory.normalCount"] as? Int,
           let highCount = workflow.outputs["AnalyzeTempHistory.highCount"] as? Int {
            print("Total readings: \(normalCount + highCount)")
            print("Normal temperature count: \(normalCount)")
            print("High temperature count: \(highCount)")
        }

        // Print the average temperature.
        if let average = workflow.outputs["AnalyzeTempHistory.average"] as? Double {
            print("Average temperature: \(average)")
        }
        // Print the median temperature.
        if let median = workflow.outputs["AnalyzeTempHistory.median"] as? Double {
            print("Median temperature: \(median)")
        }

        print("\n-------\n")

        // Generate and print the overall workflow report.
        let report = await workflow.generateReport()
        print(report.printedReport(compact: true, showOutputs: false))
    }
}
