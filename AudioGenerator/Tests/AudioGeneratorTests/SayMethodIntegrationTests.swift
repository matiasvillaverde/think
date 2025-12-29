import AbstractionsTestUtilities
@testable import AudioGenerator
import Foundation
import Testing

// MARK: - Integration Tests
// These tests validate sentence segmentation and playback orchestration using a test playback handler.

private actor PlaybackCapture {
    private var segments: [[Float]] = []

    func record(_ audio: [Float]) {
        segments.append(audio)
    }

    func count() -> Int {
        segments.count
    }

    func allSegments() -> [[Float]] {
        segments
    }
}

@Suite("Say Method Integration Tests", .serialized)
internal struct SayMethodIntegrationTests {
    @Test("Say single sentence successfully")
    func testSaySingleSentence() async {
        // Given
        let capture: PlaybackCapture = PlaybackCapture()
        let engine: AudioEngine = TestAudioEngineFactory.makeEngine { audio in
            await capture.record(audio)
        }
        let text: String = "Hello world."
        let expectedSegments: Int = await engine.breakTextIntoSentences(text).count

        // When
        await engine.say(text)

        // Then
        let segmentCount: Int = await capture.count()
        #expect(segmentCount == expectedSegments)
        let segments: [[Float]] = await capture.allSegments()
        #expect(segments.allSatisfy { !$0.isEmpty })
    }

    @Test("Orchestrate multiple sentences")
    func testSayMultipleSentences() async {
        // Given
        let capture: PlaybackCapture = PlaybackCapture()
        let engine: AudioEngine = TestAudioEngineFactory.makeEngine { audio in
            await capture.record(audio)
        }
        let text: String = "First sentence. Second sentence. Third sentence."
        let expectedSegments: Int = await engine.breakTextIntoSentences(text).count

        // When
        await engine.say(text)

        // Then
        let segmentCount: Int = await capture.count()
        #expect(segmentCount == expectedSegments)
    }

    @Test("Handle empty text in say method")
    func testSayEmptyText() async {
        // Given
        let capture: PlaybackCapture = PlaybackCapture()
        let engine: AudioEngine = TestAudioEngineFactory.makeEngine { audio in
            await capture.record(audio)
        }
        let text: String = ""
        let expectedSegments: Int = await engine.breakTextIntoSentences(text).count

        // When
        await engine.say(text)

        // Then
        let segmentCount: Int = await capture.count()
        #expect(segmentCount == expectedSegments)
    }

    @Test("Process text with mixed content")
    func testSayMixedContent() async {
        // Given
        let capture: PlaybackCapture = PlaybackCapture()
        let engine: AudioEngine = TestAudioEngineFactory.makeEngine { audio in
            await capture.record(audio)
        }
        let text: String = "Hello! How are you? I'm fine, thanks. 123 test."
        let expectedSegments: Int = await engine.breakTextIntoSentences(text).count

        // When
        await engine.say(text)

        // Then
        let segmentCount: Int = await capture.count()
        #expect(segmentCount == expectedSegments)
    }

    @Test("Handle single word without punctuation")
    func testSaySingleWord() async {
        // Given
        let capture: PlaybackCapture = PlaybackCapture()
        let engine: AudioEngine = TestAudioEngineFactory.makeEngine { audio in
            await capture.record(audio)
        }
        let text: String = "Hello"
        let expectedSegments: Int = await engine.breakTextIntoSentences(text).count

        // When
        await engine.say(text)

        // Then
        let segmentCount: Int = await capture.count()
        #expect(segmentCount == expectedSegments)
    }

    @Test("Process whitespace between sentences correctly")
    func testSayWhitespaceBetweenSentences() async {
        // Given
        let capture: PlaybackCapture = PlaybackCapture()
        let engine: AudioEngine = TestAudioEngineFactory.makeEngine { audio in
            await capture.record(audio)
        }
        let text: String = "First sentence.    \n\n   Second sentence."
        let expectedSegments: Int = await engine.breakTextIntoSentences(text).count

        // When
        await engine.say(text)

        // Then
        let segmentCount: Int = await capture.count()
        #expect(segmentCount == expectedSegments)
    }
}
