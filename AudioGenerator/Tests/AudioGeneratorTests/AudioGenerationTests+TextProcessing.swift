import AbstractionsTestUtilities
@testable import AudioGenerator
import Foundation
import Testing

extension AudioGenerationTests {
    @Test("Break single sentence correctly")
    func testSingleSentence() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = "Hello world."

        // When
        let sentences: [String] = await engine.breakTextIntoSentences(text)

        // Then
        #expect(sentences.count == 1)
        #expect(sentences[0] == "Hello world.")
    }

    @Test("Handle multiple sentences with various punctuation")
    func testMultipleSentences() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = "Hello world. How are you? This is a test! Let's try this."

        // When
        let sentences: [String] = await engine.breakTextIntoSentences(text)

        // Then
        #expect(sentences.count == 4)
        #expect(sentences[0] == "Hello world.")
        #expect(sentences[1] == "How are you?")
        #expect(sentences[2] == "This is a test!")
        #expect(sentences[3] == "Let's try this.")
    }

    @Test("Process empty text gracefully")
    func testEmptyText() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = ""

        // When
        let sentences: [String] = await engine.breakTextIntoSentences(text)

        // Then
        #expect(sentences.isEmpty)
    }

    @Test("Handle whitespace-only text")
    func testWhitespaceOnlyText() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = "   \n\t   "

        // When
        let sentences: [String] = await engine.breakTextIntoSentences(text)

        // Then
        #expect(sentences.isEmpty)
    }

    @Test("Process unicode and special characters")
    func testUnicodeAndSpecialCharacters() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = "Hello 世界! How are you? 🎉 This is great."

        // When
        let sentences: [String] = await engine.breakTextIntoSentences(text)

        // Then
        #expect(sentences.count == 3)
        #expect(sentences[0] == "Hello 世界!")
        #expect(sentences[1] == "How are you?")
        #expect(sentences[2] == "🎉 This is great.")
    }

    @Test("Handle very long text without errors")
    func testVeryLongText() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let longSentence: String = String(repeating: "This is a test sentence. ", count: 100)

        // When
        let sentences: [String] = await engine.breakTextIntoSentences(longSentence)

        // Then
        #expect(sentences.count == 100)
        #expect(sentences.allSatisfy { $0 == "This is a test sentence." })
    }

    @Test("Handle sentences without final punctuation")
    func testSentencesWithoutFinalPunctuation() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = "Hello world"

        // When
        let sentences: [String] = await engine.breakTextIntoSentences(text)

        // Then
        #expect(sentences.count == 1)
        #expect(sentences[0] == "Hello world")
    }

    @Test("Handle mixed newlines and punctuation")
    func testMixedNewlinesAndPunctuation() async {
        // Given
        let engine: AudioEngine = AudioEngine()
        let text: String = "First sentence.\nSecond sentence!\n\nThird sentence?"

        // When
        let sentences: [String] = await engine.breakTextIntoSentences(text)

        // Then
        #expect(sentences.count == 3)
        #expect(sentences[0] == "First sentence.")
        #expect(sentences[1] == "Second sentence!")
        #expect(sentences[2] == "Third sentence?")
    }
}
