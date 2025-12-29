import AbstractionsTestUtilities
@testable import AudioGenerator
import Foundation
import Testing

@Suite("Audio Generation Tests", .serialized)
internal struct AudioGenerationTests {
    @Test("Generate audio for valid text")
    func testGenerateAudioValidText() async throws {
        // Given
        let engine: AudioEngine = TestAudioEngineFactory.makeEngine()
        let text: String = "Hello world"

        // When
        let audioData: [Float] = await engine.generateAudio(text: text)

        // Then
        #expect(!audioData.isEmpty)
        #expect(audioData.count == TestAudioEngineFactory.expectedSampleCount(for: text))
        #expect(try audioData.allSatisfy(\.isFinite))
        #expect(audioData.allSatisfy { abs($0) <= 1.0 }) // Audio should be normalized
    }

    @Test("Handle empty text in audio generation")
    func testGenerateAudioEmptyText() async {
        // Given
        let engine: AudioEngine = TestAudioEngineFactory.makeEngine()
        let text: String = ""

        // When
        let audioData: [Float] = await engine.generateAudio(text: text)

        // Then
        #expect(!audioData.isEmpty)
        #expect(audioData.count == TestAudioEngineFactory.expectedSampleCount(for: text))
    }

    @Test("Process single character text")
    func testGenerateAudioSingleCharacter() async throws {
        // Given
        let engine: AudioEngine = TestAudioEngineFactory.makeEngine()
        let text: String = "A"

        // When
        let audioData: [Float] = await engine.generateAudio(text: text)

        // Then
        #expect(!audioData.isEmpty)
        #expect(audioData.count == TestAudioEngineFactory.expectedSampleCount(for: text))
        #expect(try audioData.allSatisfy(\.isFinite))
    }

    @Test("Generate audio for long text")
    func testGenerateAudioLongText() async throws {
        // Given
        let engine: AudioEngine = TestAudioEngineFactory.makeEngine()
        let text: String = "This is a longer piece of text that should generate a longer audio sample. " +
                    "It contains multiple words and should test the audio generation capabilities."

        // When
        let audioData: [Float] = await engine.generateAudio(text: text)

        // Then
        #expect(!audioData.isEmpty)
        #expect(audioData.count == TestAudioEngineFactory.expectedSampleCount(for: text))
        #expect(try audioData.allSatisfy(\.isFinite))
    }

    @Test("Handle special characters in audio generation")
    func testGenerateAudioSpecialCharacters() async throws {
        // Given
        let engine: AudioEngine = TestAudioEngineFactory.makeEngine()
        let text: String = "Hello! How are you? 123."

        // When
        let audioData: [Float] = await engine.generateAudio(text: text)

        // Then
        #expect(!audioData.isEmpty)
        #expect(audioData.count == TestAudioEngineFactory.expectedSampleCount(for: text))
        #expect(try audioData.allSatisfy(\.isFinite))
    }

    @Test("Verify audio data validity")
    func testAudioDataValidity() async {
        // Given
        let engine: AudioEngine = TestAudioEngineFactory.makeEngine()
        let text: String = "Test audio generation"

        // When
        let audioData: [Float] = await engine.generateAudio(text: text)

        // Then
        #expect(!audioData.isEmpty)
        #expect(audioData.count == TestAudioEngineFactory.expectedSampleCount(for: text))

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
