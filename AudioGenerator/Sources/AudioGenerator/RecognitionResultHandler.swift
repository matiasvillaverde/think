import Foundation
import Speech

/// A class to safely bridge between non-isolated recognition result callbacks and the actor
internal final class RecognitionResultHandler {
    /// Weak reference to the speech recognizer actor
    private weak var recognizer: SpeechRecognizer?

    init(recognizer: SpeechRecognizer) {
        self.recognizer = recognizer
    }

    /// This method can be called from non-isolated contexts like callbacks
    func handleResult(_ result: SFSpeechRecognitionResult?, _ error: Error?) {
        // Extract only the data we need
        let transcription: String? = result?.bestTranscription.formattedString
        let isFinal: Bool = result?.isFinal ?? false

        // Send to actor
        recognizer?.processRecognitionResult(transcription: transcription, isFinal: isFinal, error: error)
    }

    deinit {
        // No cleanup needed - weak reference handles memory management
    }
}
