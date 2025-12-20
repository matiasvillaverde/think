import AVFoundation
import Foundation

// swiftlint:disable force_unwrapping

internal class AudioUtils {
    enum AudioUtilsErrors: Error {
        case cannotCreateAVAudioFormat
    }

    private init() {
        // Static utility class
    }

    // Debug method to write output to .wav file for checking the speech generation
    static func writeWavFile(samples: [Float], sampleRate: Double, fileURL: URL) throws {
        let frameCount: AVAudioFrameCount = AVAudioFrameCount(samples.count)

        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else {
            throw AudioUtilsErrors.cannotCreateAVAudioFormat
        }

        buffer.frameLength = frameCount
        let channelData: UnsafeMutablePointer<Float> = buffer.floatChannelData![0]
        for i in 0 ..< Int(frameCount) {
            channelData[i] = samples[i]
        }

        let audioFile: AVAudioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )

        try audioFile.write(from: buffer)
    }

    deinit {
        // No cleanup needed - static utility class
    }
}
// swiftlint:enable force_unwrapping
