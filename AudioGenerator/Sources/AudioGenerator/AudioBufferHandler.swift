import AVFoundation
import Foundation
import Speech

/// A class to safely bridge between non-isolated audio buffer callbacks and the actor
internal final class AudioBufferHandler {
    /// Weak reference to the speech recognizer actor
    private weak var recognizer: SpeechRecognizer?

    /// Reference to the recognition request for appending buffers
    private let request: SFSpeechAudioBufferRecognitionRequest

    init(recognizer: SpeechRecognizer, request: SFSpeechAudioBufferRecognitionRequest) {
        self.recognizer = recognizer
        self.request = request
    }

    /// This method can be called from non-isolated contexts like callbacks
    func handleBuffer(_ buffer: AVAudioPCMBuffer) {
        // Append buffer directly to the request (no actor isolation needed)
        request.append(buffer)

        // Notify the actor that audio was received, passing the buffer for level calculation
        recognizer?.audioBufferReceived(buffer: buffer)
    }

    deinit {
        // No cleanup needed - weak reference handles memory management
    }
}
