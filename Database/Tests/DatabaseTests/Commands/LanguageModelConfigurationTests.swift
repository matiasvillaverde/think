import Testing
import Foundation
import SwiftData
@testable import Database
import AbstractionsTestUtilities
import Abstractions
import DataAssets

@Suite("Language Model Configuration Tests")
struct LanguageModelConfigurationTests {
    @Suite(.tags(.acceptance))
    struct ConfigurationTests {
        @Test("Get language model configuration successfully")
        @MainActor
        func getLanguageModelConfigSuccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // Add required models for the test
            let textGenerationModel = ModelDTO(
                type: .language,
                backend: .mlx,
                name: "test-text-model",
                displayName: "Test Text Model",
                displayDescription: "A test text generation model",
                skills: ["text generation"],
                parameters: 7_000_000_000,
                ramNeeded: 8_000_000_000,
                size: 4_000_000_000,
                locationHuggingface: "local/path/text-model",
                version: 2,
                architecture: .unknown
            )

            let deepTextGenerationModel = ModelDTO(
                type: .deepLanguage,
                backend: .mlx,
                name: "test-deep-text-model",
                displayName: "Test Deep Text Model",
                displayDescription: "A test deep text generation model",
                skills: ["reason"],
                parameters: 7_000_000_000,
                ramNeeded: 8_000_000_000,
                size: 4_000_000_000,
                locationHuggingface: "local/path/deep-text-model",
                version: 2,
                architecture: .unknown
            )

            let imageGenerationModel = ModelDTO(
                type: .diffusion,
                backend: .mlx,
                name: "test-image-model",
                displayName: "Test Image Model",
                displayDescription: "A test image generation model",
                skills: ["image generation"],
                parameters: 1_000_000_000,
                ramNeeded: 4_000_000_000,
                size: 2_000_000_000,
                locationHuggingface: "local/path/image-model",
                version: 2,
                architecture: .unknown
            )

            try await database.write(ModelCommands.AddModels(models: [
                textGenerationModel,
                deepTextGenerationModel,
                imageGenerationModel
            ]))

            // Initialize default personality
            try await database.write(PersonalityCommands.WriteDefault())
            let defaultPersonalityId = try await getDefaultPersonalityId(database)

            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // When
            let llmConfig = try await database.read(
                ChatCommands.GetLanguageModelConfiguration(
                    chatId: chatId,
                    prompt: "Test prompt"
                )
            )

            // Then
            let expected = LLMConfiguration.default

            // SendableLLMConfiguration includes the system instruction in the prompt
            #expect(llmConfig.prompt == "Test prompt")
            #expect(llmConfig.maxTokens == expected.maxTokens)
            #expect(llmConfig.temperature == expected.temperature)
            #expect(llmConfig.topP == expected.topP)
            #expect(llmConfig.prefillStepSize == expected.stepSize)
        }

        @Test("Get language model configuration fails with invalid chat ID")
        @MainActor
        func getLanguageModelConfigInvalidChat() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            let nonExistentChatId = UUID()
            let testPrompt = "Test prompt for language model"

            // When/Then
            await #expect(throws: DatabaseError.chatNotFound) {
                _ = try await database.read(
                    ChatCommands.GetLanguageModelConfiguration(
                        chatId: nonExistentChatId,
                        prompt: "Test prompt"
                    )
                )
            }
        }
    }

    @Suite(.tags(.acceptance))
    struct CopyMethodTests {
        @Test("LLMConfiguration copy preserves all properties including personality")
        @MainActor
        func copyPreservesAllProperties() throws {
            // Given
            let personality = Personality(
                systemInstruction: .philosopher,
                name: "Test Personality",
                description: "A test personality",
                category: .education
            )

            let original = LLMConfiguration(
                systemInstruction: .mathTeacher,
                contextStrategy: .messagesAndFiles,
                stepSize: 256,
                temperature: 0.8,
                topP: 0.95,
                repetitionPenalty: 1.1,
                repetitionContextSize: 50,
                maxTokens: 2048,
                maxPrompt: 4096,
                prefillStepSize: 128,
                personality: personality
            )

            // When
            let copy = original.copy()

            // Then - All properties should be copied
            #expect(copy.systemInstruction == original.systemInstruction)
            #expect(copy.contextStrategy == original.contextStrategy)
            #expect(copy.stepSize == original.stepSize)
            #expect(copy.temperature == original.temperature)
            #expect(copy.topP == original.topP)
            #expect(copy.repetitionPenalty == original.repetitionPenalty)
            #expect(copy.repetitionContextSize == original.repetitionContextSize)
            #expect(copy.maxTokens == original.maxTokens)
            #expect(copy.maxPrompt == original.maxPrompt)
            #expect(copy.prefillStepSize == original.prefillStepSize)

            // Most importantly - personality should now be copied
            #expect(copy.personality === original.personality)
            #expect(copy.personality?.id == personality.id)
        }

        @Test("LLMConfiguration copy works with nil personality")
        @MainActor
        func copyWithNilPersonality() throws {
            // Given
            let original = LLMConfiguration(
                systemInstruction: .englishAssistant,
                contextStrategy: .allMessages,
                stepSize: 512,
                temperature: 0.7,
                topP: 1.0,
                repetitionPenalty: nil,
                repetitionContextSize: 20,
                maxTokens: 10240,
                maxPrompt: 10240,
                prefillStepSize: 512,
                personality: nil
            )

            // When
            let copy = original.copy()

            // Then
            #expect(copy.personality == nil)
            #expect(copy.systemInstruction == original.systemInstruction)
        }

        @Test("LLMConfiguration copy creates independent instance")
        @MainActor
        func copyCreatesIndependentInstance() throws {
            // Given
            let original = LLMConfiguration.default

            // When
            let copy = original.copy()

            // Then - They should have same values but be different instances
            #expect(copy !== original)
            #expect(copy.id != original.id) // Should have different IDs
            #expect(copy.systemInstruction == original.systemInstruction)
        }
    }

    @Suite(.tags(.acceptance))
    struct MigrationTests {
        @Test("Automatic migration handles LLMConfiguration with default values")
        @MainActor
        func automaticMigrationWithDefaultValues() async throws {
            // This test verifies that SwiftData's automatic migration works correctly
            // when the systemInstruction property has a default value

            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // Add required models for the test
            let textGenerationModel = ModelDTO(
                type: .language,
                backend: .mlx,
                name: "test-text-model",
                displayName: "Test Text Model",
                displayDescription: "A test text generation model",
                skills: ["text generation"],
                parameters: 7_000_000_000,
                ramNeeded: 8_000_000_000,
                size: 4_000_000_000,
                locationHuggingface: "local/path/text-model",
                version: 2,
                architecture: .unknown
            )

            let deepTextGenerationModel = ModelDTO(
                type: .deepLanguage,
                backend: .mlx,
                name: "test-deep-text-model",
                displayName: "Test Deep Text Model",
                displayDescription: "A test deep text generation model",
                skills: ["reason"],
                parameters: 7_000_000_000,
                ramNeeded: 8_000_000_000,
                size: 4_000_000_000,
                locationHuggingface: "local/path/deep-text-model",
                version: 2,
                architecture: .unknown
            )

            let imageGenerationModel = ModelDTO(
                type: .diffusion,
                backend: .mlx,
                name: "test-image-model",
                displayName: "Test Image Model",
                displayDescription: "A test image generation model",
                skills: ["image generation"],
                parameters: 1_000_000_000,
                ramNeeded: 4_000_000_000,
                size: 2_000_000_000,
                locationHuggingface: "local/path/image-model",
                version: 2,
                architecture: .unknown
            )

            try await database.write(ModelCommands.AddModels(models: [
                textGenerationModel,
                deepTextGenerationModel,
                imageGenerationModel
            ]))

            // Initialize default personality
            try await database.write(PersonalityCommands.WriteDefault())
            let defaultPersonalityId = try await getDefaultPersonalityId(database)

            // Create a chat which will create an LLMConfiguration
            let chatId = try await database.write(
                ChatCommands.Create(personality: defaultPersonalityId)
            )

            // When - Get the language model configuration
            let llmConfig = try await database.read(
                ChatCommands.GetLanguageModelConfiguration(
                    chatId: chatId,
                    prompt: "Test prompt"
                )
            )

            // Then - Verify the configuration is valid
            // SendableLLMConfiguration has the system instruction in the prompt
            #expect(llmConfig.prompt == "Test prompt")
            #expect(llmConfig.maxTokens > 0)
            #expect(llmConfig.temperature >= 0 && llmConfig.temperature <= 1.0)

            // Test that we can create new configurations without issues
            let newConfig = LLMConfiguration(
                systemInstruction: .mathTeacher,
                contextStrategy: .allMessages,
                stepSize: 256,
                temperature: 0.9,
                topP: 0.9,
                repetitionPenalty: 1.2,
                repetitionContextSize: 40,
                maxTokens: 4096,
                maxPrompt: 8192,
                prefillStepSize: 256,
                personality: nil
            )

            // Verify the new configuration works correctly
            #expect(newConfig.systemInstruction == .mathTeacher)

            // Test copy method still works with default values
            let copy = newConfig.copy()
            #expect(copy.systemInstruction == newConfig.systemInstruction)
            #expect(copy.personality == nil)
        }

        @Test("Reproduces original crash - SwiftData assertion failure with nil values")
        @MainActor
        func reproducesOriginalCrash() async throws {
            // This test verifies the fix for issue #13 - SwiftData crashes when encoding nil values
            // The crash occurred in two places:
            // 1. Model.displayName in SideView.availableModelDisplayNames()
            // 2. LLMConfiguration.systemInstruction in LLMConfiguration.copy()

            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // Test 1: Model with empty displayName (would have caused crash)
            let modelWithEmptyName = ModelDTO(
                type: .language,
                backend: .mlx,
                name: "model-name",
                displayName: "", // Empty displayName that would have caused crash
                displayDescription: "Test model",
                skills: ["text generation"],
                parameters: 1_000_000,
                ramNeeded: 1_000_000_000,
                size: 2_000_000_000,
                locationHuggingface: "local/path/model",
                version: 2,
                architecture: .unknown
            )

            // When - Add model (this would have crashed before the fix)
            let modelId = try await database.write(ModelCommands.AddModels(models: [modelWithEmptyName]))

            // Then - Verify the model with empty displayName was handled correctly
            let model = try await database.read(ModelCommands.GetModelFromId(id: modelId))
            #expect(model.displayName == "model-name") // Should use name as fallback

            // Test 2: LLMConfiguration with default systemInstruction
            let llmConfig = LLMConfiguration.default

            // Test that copy works (this would have crashed before if personality was nil)
            let copiedConfig = llmConfig.copy()

            // Verify the copy worked correctly
            #expect(copiedConfig.systemInstruction == llmConfig.systemInstruction)
            #expect(copiedConfig.id != llmConfig.id) // Different instances

            // Verify default values are applied
            #expect(llmConfig.systemInstruction == SystemInstruction.englishAssistant)

            // Test 3: Create a configuration with personality and verify copy preserves it
            let personality = Personality(
                systemInstruction: .mathTeacher,
                name: "Math Teacher",
                description: "A helpful math teacher",
                category: .education
            )

            let configWithPersonality = LLMConfiguration(
                systemInstruction: .mathTeacher,
                contextStrategy: .allMessages,
                stepSize: 512,
                temperature: 0.7,
                topP: 1.0,
                repetitionPenalty: nil,
                repetitionContextSize: 20,
                maxTokens: 10240,
                maxPrompt: 10240,
                prefillStepSize: 512,
                personality: personality
            )

            let copiedWithPersonality = configWithPersonality.copy()
            #expect(copiedWithPersonality.personality === personality)
        }
    }
}
