import AbstractionsTestUtilities
@testable import AudioGenerator
import Foundation
import Testing

@Suite("Audio Generation Tests", .serialized)
internal struct AudioGenerationTests {
    @Test("Generate audio for valid text")
    func testGenerateAudioValidText() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = "Hello world"

        // When
        let audioData: [Float] = await engine.generateAudio(text: text)

        // Then
        #expect(!audioData.isEmpty)
        #expect(audioData.count == 37_800) // Exact audio length for "Hello world"
        #expect(audioData.allSatisfy { $0.isFinite }) // swiftlint:disable:this prefer_key_path
        #expect(audioData.allSatisfy { abs($0) <= 1.0 }) // Audio should be normalized
    }

    @Test("Handle empty text in audio generation")
    func testGenerateAudioEmptyText() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = ""

        // When
        let audioData: [Float] = await engine.generateAudio(text: text)

        // Then
        #expect(!audioData.isEmpty) // KokoroTTS generates minimal audio for empty text
        #expect(audioData.count == 9_000) // Exact audio length for empty text
    }

    @Test("Process single character text")
    func testGenerateAudioSingleCharacter() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = "A"

        // When
        let audioData: [Float] = await engine.generateAudio(text: text)

        // Then
        #expect(!audioData.isEmpty)
        #expect(audioData.count == 31_800) // Exact audio length for "A"
        #expect(audioData.allSatisfy { $0.isFinite }) // swiftlint:disable:this prefer_key_path
    }

    @Test("Generate audio for long text")
    func testGenerateAudioLongText() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = "This is a longer piece of text that should generate a longer audio sample. " +
                    "It contains multiple words and should test the audio generation capabilities."

        // When
        let audioData: [Float] = await engine.generateAudio(text: text)

        // Then
        #expect(!audioData.isEmpty)
        #expect(audioData.count == 255_600) // Exact audio length for long text
        #expect(audioData.allSatisfy { $0.isFinite }) // swiftlint:disable:this prefer_key_path
    }

    @Test("Handle special characters in audio generation")
    func testGenerateAudioSpecialCharacters() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = "Hello! How are you? 123."

        // When
        let audioData: [Float] = await engine.generateAudio(text: text)

        // Then
        #expect(!audioData.isEmpty)
        #expect(audioData.count == 61_800) // Exact audio length for "Hello! How are you? 123."
        #expect(audioData.allSatisfy { $0.isFinite }) // swiftlint:disable:this prefer_key_path
    }

    @Test("Verify audio data validity")
    func testAudioDataValidity() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = "Test audio generation"

        // When
        let audioData: [Float] = await engine.generateAudio(text: text)

        // Then
        #expect(!audioData.isEmpty)
        #expect(audioData.count == 51_600) // Exact audio length for "Test audio generation"

        // Check for reasonable audio characteristics
        let maxValue: Float = audioData.max() ?? 0
        let minValue: Float = audioData.min() ?? 0
        #expect(maxValue <= 1.0)
        #expect(minValue >= -1.0)

        // Check for non-zero audio (not silence)
        let hasNonZeroValues: Bool = audioData.contains { $0 != 0 }
        #expect(hasNonZeroValues)
    }
}
