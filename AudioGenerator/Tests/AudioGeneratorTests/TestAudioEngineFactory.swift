@testable import AudioGenerator
import Foundation

internal enum TestAudioEngineFactory {
    private static let samplesPerCharacter: Int = 100
    private static let minimumSamples: Int = 100
    private static let sampleValue: Float = 0.1

    static func makeEngine(
        playbackHandler: (@Sendable ([Float]) async -> Void)? = nil
    ) -> AudioEngine {
        let generator: AudioEngine.AudioGenerator = { text in
            let count: Int = expectedSampleCount(for: text)
            return Array(repeating: sampleValue, count: count)
        }

        if let playbackHandler {
            return AudioEngine(playbackHandler: playbackHandler, audioGenerator: generator)
        }

        return AudioEngine(audioGenerator: generator)
    }

    static func expectedSampleCount(for text: String) -> Int {
        max(minimumSamples, text.count * samplesPerCharacter)
    }
}
