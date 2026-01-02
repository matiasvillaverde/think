import Foundation
import Testing
@testable import Abstractions

@Suite("Enhanced Tool Protocol Tests")
struct EnhancedToolProtocolTests {
    @Test("ToolExample should be properly initialized")
    func toolExampleInitialization() {
        // Given
        let scenario = "User asks for weather"
        let input = "{\"location\": \"San Francisco\"}"
        let expectedBehavior = "Returns current weather data for San Francisco"

        // When
        let example = ToolExample(
            scenario: scenario,
            input: input,
            expectedBehavior: expectedBehavior
        )

        // Then
        #expect(example.scenario == scenario)
        #expect(example.input == input)
        #expect(example.expectedBehavior == expectedBehavior)
    }

    @Test("ToolExample should be Codable")
    func toolExampleCodable() throws {
        // Given
        let example = ToolExample(
            scenario: "Calculate sum",
            input: "{\"a\": 5, \"b\": 3}",
            expectedBehavior: "Returns {\"result\": 8}"
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(example)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolExample.self, from: data)

        // Then
        #expect(decoded.scenario == example.scenario)
        #expect(decoded.input == example.input)
        #expect(decoded.expectedBehavior == example.expectedBehavior)
    }

    @Test("InteractionPattern should have correct raw values")
    func interactionPatternRawValues() {
        // Then
        #expect(InteractionPattern.single.rawValue == "single")
        #expect(InteractionPattern.sequential.rawValue == "sequential")
        #expect(InteractionPattern.requiresContext.rawValue == "requires_context")
    }

    @Test("InteractionPattern should be Codable")
    func interactionPatternCodable() throws {
        // Given
        let patterns: [InteractionPattern] = [.single, .sequential, .requiresContext]

        for pattern in patterns {
            // When
            let encoder = JSONEncoder()
            let data = try encoder.encode(pattern)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(InteractionPattern.self, from: data)

            // Then
            #expect(decoded == pattern)
        }
    }

    @Test("EnhancedToolMetadata should properly initialize with all fields")
    func enhancedToolMetadataFullInitialization() {
        // Given
        let examples = [
            ToolExample(
                scenario: "Search for information",
                input: "{\"query\": \"Swift programming\"}",
                expectedBehavior: "Returns search results about Swift"
            )
        ]
        let prerequisites = ["Internet connection required", "API key must be configured"]

        // When
        let metadata = EnhancedToolMetadata(
            usageInstruction: "Use when user needs web search",
            examples: examples,
            interactionPattern: .sequential,
            prerequisites: prerequisites,
            bestPractices: "Limit results to 10 for better performance"
        )

        // Then
        #expect(metadata.usageInstruction == "Use when user needs web search")
        #expect(metadata.examples.count == 1)
        #expect(metadata.examples.first?.scenario == "Search for information")
        #expect(metadata.interactionPattern == .sequential)
        #expect(metadata.prerequisites.count == 2)
        #expect(metadata.bestPractices == "Limit results to 10 for better performance")
    }

    @Test("EnhancedToolMetadata should allow empty values for collection fields")
    func enhancedToolMetadataEmptyFields() {
        // When
        let metadata = EnhancedToolMetadata()

        // Then
        #expect(metadata.usageInstruction == nil)
        #expect(metadata.examples.isEmpty)
        #expect(metadata.interactionPattern == nil)
        #expect(metadata.prerequisites.isEmpty)
        #expect(metadata.bestPractices == nil)
    }

    @Test("EnhancedToolMetadata should be Sendable")
    func enhancedToolMetadataSendable() async {
        // Given
        let metadata = EnhancedToolMetadata(
            usageInstruction: "Test instruction",
            interactionPattern: .single
        )

        // When - This should compile if Sendable
        await Task {
            _ = metadata
        }.value

        // Then
        #expect(metadata.usageInstruction == "Test instruction")
    }

    @Test("Mock enhanced tool should conform to protocol")
    func mockEnhancedToolConformance() {
        // Given
        struct MockEnhancedTool: EnhancedToolProtocol {
            var usageInstruction: String? = "Mock usage"
            var examples: [ToolExample] = []
            var interactionPattern: InteractionPattern? = .single
            var prerequisites: [String] = []
            var bestPractices: String?
        }

        // When
        let mockTool = MockEnhancedTool()

        // Then
        #expect(mockTool.usageInstruction == "Mock usage")
        #expect(mockTool.interactionPattern == .single)
    }

    @Test("ToolExample arrays should be equatable")
    func toolExampleArrayEquatable() {
        // Given
        let examples1 = [
            ToolExample(scenario: "A", input: "1", expectedBehavior: "X"),
            ToolExample(scenario: "B", input: "2", expectedBehavior: "Y")
        ]
        let examples2 = [
            ToolExample(scenario: "A", input: "1", expectedBehavior: "X"),
            ToolExample(scenario: "B", input: "2", expectedBehavior: "Y")
        ]
        let examples3 = [
            ToolExample(scenario: "C", input: "3", expectedBehavior: "Z")
        ]

        // Then
        #expect(examples1 == examples2)
        #expect(examples1 != examples3)
    }

    @Test("EnhancedToolMetadata should be Codable")
    func enhancedToolMetadataCodable() throws {
        // Given
        let metadata = EnhancedToolMetadata(
            usageInstruction: "Test usage",
            examples: [
                ToolExample(scenario: "Test", input: "{}", expectedBehavior: "Works")
            ],
            interactionPattern: .requiresContext,
            prerequisites: ["Requirement 1"],
            bestPractices: "Best practice"
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(EnhancedToolMetadata.self, from: data)

        // Then
        #expect(decoded.usageInstruction == metadata.usageInstruction)
        #expect(decoded.examples.count == metadata.examples.count)
        #expect(decoded.interactionPattern == metadata.interactionPattern)
        #expect(decoded.prerequisites == metadata.prerequisites)
        #expect(decoded.bestPractices == metadata.bestPractices)
    }
}
