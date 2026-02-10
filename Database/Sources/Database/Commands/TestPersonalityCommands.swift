import Foundation
import SwiftData
import OSLog
import Abstractions
import DataAssets

// MARK: - Test-Specific Personality Commands
public enum TestPersonalityCommands {
    /// Creates a test personality with the ChatGPT system instruction
    /// Used specifically for tests that expect this exact text
    public struct CreateChatGPTTestPersonality: WriteCommand {
        public typealias Result = UUID
        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        private let includeCurrentDate: Bool
        private let knowledgeCutoffDate: String?
        private let currentDateOverride: String?

        public init(
            includeCurrentDate: Bool = true,
            knowledgeCutoffDate: String? = "2024-06",
            currentDateOverride: String? = "2025-06-28"
        ) {
            self.includeCurrentDate = includeCurrentDate
            self.knowledgeCutoffDate = knowledgeCutoffDate
            self.currentDateOverride = currentDateOverride
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            // Create a unique name for this test personality configuration
            let configHash = "\(includeCurrentDate)_\(knowledgeCutoffDate ?? "none")_\(currentDateOverride ?? "none")"
            let uniqueName = "ChatGPT Test Assistant \(configHash)"

            // Check if this exact configuration already exists
            let descriptor = FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { 
                    $0.name == uniqueName && !$0.isCustom 
                }
            )

            if let existing = try context.fetch(descriptor).first {
                Logger.database.info("Test personality already exists with ID: \(existing.id)")
                return existing.id
            }

            // Build the system instruction dynamically based on parameters
            var instructionParts: [String] = ["You are ChatGPT, a large language model trained by OpenAI."]

            if let knowledgeCutoff = knowledgeCutoffDate {
                instructionParts.append("Knowledge cutoff: \(knowledgeCutoff)")
            }

            if includeCurrentDate, let currentDate = currentDateOverride {
                instructionParts.append("Current date: \(currentDate)")
            }

            instructionParts.append("")  // Empty line

            instructionParts.append(
                "# Valid channels: analysis, commentary, final. Channel must be included for every message."
            )

            let harmonySystemInstruction = instructionParts.joined(separator: "\n")
            let testPersonality = Personality(
                systemInstruction: .custom(harmonySystemInstruction),
                name: uniqueName,
                description: "Test personality for Harmony acceptance tests",
                imageName: "think",
                category: .productivity,
                isDefault: false,
                isCustom: false  // System personality for tests
            )

            context.insert(testPersonality)

            Logger.database.info("Created ChatGPT test personality with ID: \(testPersonality.id)")
            return testPersonality.id
        }
    }
}
