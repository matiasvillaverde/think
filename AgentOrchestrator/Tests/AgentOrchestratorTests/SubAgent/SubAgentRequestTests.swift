import Abstractions
import Foundation
import Testing

@testable import AgentOrchestrator

/// Tests for SubAgentRequest
@Suite("SubAgentRequest Tests")
internal struct SubAgentRequestTests {
    @Test("Request initializes with required fields")
    internal func requestInitializesWithRequiredFields() {
        let parentMessageId: UUID = UUID()
        let parentChatId: UUID = UUID()
        let prompt: String = "Research topic"

        let request: SubAgentRequest = SubAgentRequest(
            parentMessageId: parentMessageId,
            parentChatId: parentChatId,
            prompt: prompt
        )

        #expect(request.parentMessageId == parentMessageId)
        #expect(request.parentChatId == parentChatId)
        #expect(request.prompt == prompt)
        #expect(request.mode == .background)
        #expect(request.tools.isEmpty)
    }

    @Test("Request initializes with all fields")
    internal func requestInitializesWithAllFields() {
        let customId: UUID = UUID()
        let tools: Set<ToolIdentifier> = [.browser, .duckduckgo]

        let request: SubAgentRequest = SubAgentRequest(
            parentMessageId: UUID(),
            parentChatId: UUID(),
            prompt: "Task",
            id: customId,
            tools: tools,
            mode: .parallel,
            timeout: .seconds(60),
            systemInstruction: "Be helpful"
        )

        #expect(request.id == customId)
        #expect(request.tools == tools)
        #expect(request.mode == .parallel)
        #expect(request.systemInstruction == "Be helpful")
    }
}
