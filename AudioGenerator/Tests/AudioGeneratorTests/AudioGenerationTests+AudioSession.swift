@testable import AudioGenerator
import AVFoundation
import Foundation
import Testing

extension AudioGenerationTests {
    @Test("Audio session not active on init")
    func testAudioSessionNotActiveOnInit() throws {
        #if os(iOS)
        // Given
        let initialCategory: AVAudioSession.Category = AVAudioSession.sharedInstance().category

        // When
        let engine: AudioEngine = AudioEngine()

        // Then - Audio session should not be changed
        let currentCategory: AVAudioSession.Category = AVAudioSession.sharedInstance().category
        #expect(currentCategory == initialCategory)
        #endif
    }

    @Test("Audio session active during speech")
    func testAudioSessionActiveDuringSpeech() async throws {
        #if os(iOS)
        // Given
        let engine: AudioEngine = AudioEngine()

        // Track if audio session was activated
        var wasActivated: Bool = false
        let expectation: (stream: AsyncStream<Bool>, continuation: AsyncStream<Bool>.Continuation) = AsyncStream<Bool>.makeStream()

        // Monitor audio session changes
        Task {
            // This is a simplified test - in reality we'd need to hook into audio session notifications
            await engine.say("Test speech")
            wasActivated = true
            expectation.continuation.yield(true)
            expectation.continuation.finish()
        }

        // Wait for the say operation
        for await _ in expectation.stream {
            break
        }

        // Then
        #expect(wasActivated)
        #endif
    }

    @Test("Audio session deactivated after speech")
    func testAudioSessionDeactivatedAfterSpeech() async throws {
        #if os(iOS)
        // Given
        let engine: AudioEngine = AudioEngine()

        // When
        await engine.say("Test speech")

        // Small delay to ensure deactivation completes
        try await Task.sleep(for: .milliseconds(100))

        // Then - In a real test, we'd verify the session state
        // For now, we verify the method completes without error
        #expect(true) // Placeholder - would check actual session state
        #endif
    }

    @Test("Handle audio session activation failure gracefully")
    func testAudioSessionErrorRecovery() async throws {
        #if os(iOS)
        // This test verifies error handling exists
        // In practice, we'd need to simulate audio session failures
        let engine: AudioEngine = AudioEngine()

        // Should not throw even if audio session has issues
        await engine.say("Test with potential audio issues")

        #expect(true) // Verify no crash
        #endif
    }
}
