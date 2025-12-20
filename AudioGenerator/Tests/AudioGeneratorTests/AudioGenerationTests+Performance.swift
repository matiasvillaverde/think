import AbstractionsTestUtilities
@testable import AudioGenerator
import Foundation
import Testing

extension AudioGenerationTests {
    @Test("Test execution completes quickly")
    func testExecutionSpeed() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = "Quick test."
        _ = await engine.generateAudio(text: text)
        let startTime: Date = Date()

        // When
        let sentences: [String] = await engine.breakTextIntoSentences(text)
        let audioData: [Float] = await engine.generateAudio(text: text)

        // Then
        let executionTime: TimeInterval = Date().timeIntervalSince(startTime)
        #expect(executionTime < 4.0) // Warm cache should complete within 4 seconds
        #expect(!sentences.isEmpty)
        #expect(!audioData.isEmpty)
        #expect(audioData.count == 36_600) // Exact audio length for "Quick test."
    }
}
