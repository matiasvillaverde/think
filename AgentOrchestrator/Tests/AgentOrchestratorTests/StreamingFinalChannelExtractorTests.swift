@testable import AgentOrchestrator
import Foundation
import Testing

@Suite("StreamingFinalChannelExtractor Tests")
internal struct StreamingFinalChannelExtractorTests {
    @Test("Extracts final channel content from Harmony-like output")
    internal func extractsFinalContent() {
        let output: String = """
        <|start|>assistant
        <|channel|>analysis<|message|>think<|end|>
        <|channel|>final<|message|>Hello there!<|end|>
        """
        #expect(StreamingFinalChannelExtractor.extract(from: output) == "Hello there!")
    }

    @Test("Handles partial final channel without terminator")
    internal func extractsPartialFinal() {
        let output: String = """
        <|start|>assistant
        <|channel|>final<|message|>Hello
        """
        #expect(StreamingFinalChannelExtractor.extract(from: output) == "Hello")
    }

    @Test("Falls back to raw output when no final marker is present")
    internal func fallsBackToRaw() {
        let output: String = "Plain text response"
        #expect(StreamingFinalChannelExtractor.extract(from: output) == output)
    }
}
