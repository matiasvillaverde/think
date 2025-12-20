import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
import Database
import Foundation
import SwiftData
import Testing

/// Complex agentic flow tests
@Suite("Complex Agentic Flow Acceptance", .tags(.acceptance))
internal struct ComplexAgenticFlowAcceptanceTests {
    @Test("Complex Multi-Tool Travel Planning Flow - 10+ Channels")
    @MainActor
    internal func complexTravelPlanningFlow() async throws {
        // Given: Environment with multiple tool strategies
        let environment: ComplexTestEnvironment = try await ComplexTestEnvironment.create()
        await environment.configureComplexTravelFlow()

        let userInput: String = "Plan a Paris trip with weather, budget, and attractions"

        // When: Execute complex multi-tool flow
        try await environment.orchestrator.load(chatId: environment.chatId)

        try await environment.orchestrator.generate(
            prompt: userInput,
            action: .textGeneration([])
        )

        // Then: Verify complex flow with 10+ channels
        try await verifyComplexFlowResults(environment: environment)
    }

    @MainActor
    private func verifyComplexFlowResults(environment: ComplexTestEnvironment) async throws {
        let messages: [Message] = try await environment.database.read(
            MessageCommands.GetAll(chatId: environment.chatId)
        )
        #expect(messages.count == 1)

        let message: Message = messages[0]
        let channels: [Channel] = message.sortedChannels

        try verifyChannelCounts(channels: channels)
        try verifyToolUsage(channels: channels)
        try verifyFinalResponse(channels: channels)

        print("✅ Complex flow completed with \(channels.count) channels")
    }

    private func verifyChannelCounts(channels: [Channel]) throws {
        print("DEBUG: Complex flow generated \(channels.count) channels:")
        for (index, channel) in channels.enumerated() {
            let toolInfo: String = channel.toolExecution?.request?.name ?? "no tool"
            print("  Channel \(index): type=\(channel.type), tool=\(toolInfo)")
        }

        #expect(channels.count >= 10, "Should generate at least 10 channels")

        let commentaryCount: Int = channels.filter { $0.type == .commentary }.count
        let toolCount: Int = channels.filter { $0.type == .tool }.count
        let finalCount: Int = channels.filter { $0.type == .final }.count

        #expect(commentaryCount >= 5, "Should have multiple commentary channels")
        #expect(toolCount >= 5, "Should use multiple tools")
        #expect(finalCount == 1, "Should have one final response")
    }

    private func verifyToolUsage(channels: [Channel]) throws {
        let toolNames: [String] = channels.compactMap { $0.toolExecution?.request?.name }
        let expectedTools: [String] = ["weather", "location", "calculator", "calendar", "news"]

        for tool in expectedTools {
            #expect(toolNames.contains(tool), "Should use \(tool) tool")
        }

        for channel in channels where channel.type == .tool {
            if let execution = channel.toolExecution {
                #expect(execution.state == .completed, "Tool should be completed")
                #expect(execution.response != nil, "Tool should have response")
            }
        }
    }

    private func verifyFinalResponse(channels: [Channel]) throws {
        let finalChannel: Channel? = channels.first { $0.type == .final }
        guard let final = finalChannel else {
            #expect(Bool(false), "Should have final response")
            return
        }

        #expect(final.content.contains("Weather"), "Should include weather")
        #expect(final.content.contains("Budget"), "Should include budget")
        #expect(final.content.contains("€630"), "Should include total")
    }
}
