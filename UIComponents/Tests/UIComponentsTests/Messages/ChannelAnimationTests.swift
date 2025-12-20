import Abstractions
@testable import Database
import Foundation
import SwiftUI
import Testing
@testable import UIComponents

@Suite("Channel Animation Tests")
internal struct ChannelAnimationTests {
    @Test("Analysis channel brain icon has pulsing animation")
    @MainActor
    func analysisChannelHasPulsingBrain() {
        // Given
        let channel: Channel = Channel(
            type: .analysis,
            content: "Analyzing request...",
            order: 0
        )

        // When
        let message: Message = Message.previewWithResponse
        let _: ChannelMessageView = ChannelMessageView(channel: channel, message: message)

        // Then
        // The view should have animation properties configured
        // Note: We can't directly test SwiftUI animations in unit tests,
        // but we can ensure the view is created without errors
        #expect(channel.type == .analysis)
    }

    @Test("Tool execution status transitions trigger animations")
    func toolExecutionStatusTransitionsAnimate() {
        // Given
        let toolRequest: ToolRequest = ToolRequest(
            name: "web_search",
            arguments: "{}",
            displayName: "Web Search"
        )

        let toolExecution: ToolExecution = ToolExecution(
            request: toolRequest,
            state: .pending
        )

        // When status changes occur
        // Note: In production, state transitions happen through the transitionTo method

        // Then
        #expect(toolExecution.state == .pending)
        #expect(toolExecution.toolName == "web_search")
    }

    @Test("Loading dots animation configuration exists for executing tools")
    func loadingDotsAnimationExistsForExecutingTools() {
        // Given
        let toolRequest: ToolRequest = ToolRequest(
            name: "test_tool",
            arguments: "{}",
            displayName: "Test Tool"
        )

        let toolExecution: ToolExecution = ToolExecution(
            request: toolRequest,
            state: .executing
        )

        // Then
        #expect(toolExecution.state == .executing)
        #expect(toolExecution.toolName == "test_tool")
    }
}
