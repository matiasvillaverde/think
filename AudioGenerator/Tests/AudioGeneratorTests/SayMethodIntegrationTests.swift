import AbstractionsTestUtilities
@testable import AudioGenerator
import Foundation
import Testing

// MARK: - Integration Tests
// These tests involve the full audio playback pipeline and cannot be automatically verified.
// They are disabled by default and should only be run manually to verify audio output.

@Suite("Say Method Integration Tests", .serialized, .disabled("Run manually to verify audio playback - requires human verification"))
internal struct SayMethodIntegrationTests {
    @Test("Say single sentence successfully")
    func testSaySingleSentence() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = "Hello world."

        // When
        await engine.say(text)

        // Then
        // Test completes without throwing - audio generation and queueing worked
        // Human verification required to confirm audio was heard
    }

    @Test("Orchestrate multiple sentences")
    func testSayMultipleSentences() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = "First sentence. Second sentence. Third sentence."

        // When
        await engine.say(text)

        // Then
        // Test completes without throwing - multiple audio segments were processed
        // Human verification required to confirm all sentences were heard in order
    }

    @Test("Handle empty text in say method")
    func testSayEmptyText() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = ""

        // When
        await engine.say(text)

        // Then
        // Should return immediately without processing
        // No audio should be played
    }

    @Test("Process text with mixed content")
    func testSayMixedContent() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = "Hello! How are you? I'm fine, thanks. 123 test."

        // When
        await engine.say(text)

        // Then
        // Should process all content types
        // Human verification required to confirm mixed content was spoken correctly
    }

    @Test("Handle single word without punctuation")
    func testSaySingleWord() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = "Hello"

        // When
        await engine.say(text)

        // Then
        // Should process single word
        // Human verification required to confirm word was spoken
    }

    @Test("Process whitespace between sentences correctly")
    func testSayWhitespaceBetweenSentences() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = "First sentence.    \n\n   Second sentence."

        // When
        await engine.say(text)

        // Then
        // Should handle whitespace correctly
        // Human verification required to confirm proper sentence separation
    }
}
