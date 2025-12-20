import Foundation

/// Errors that can occur during speech recognition
public enum RecognizerError: Error, LocalizedError {
    case alreadyListening
    case audioSessionInterrupted
    case audioSessionSetupFailed(Error)
    case authorizationDenied
    case microphonePermissionDenied
    case noSpeechDetected
    case recognitionCancelled
    case recognitionFailed(Error)
    case recognizerUnavailable

    public var errorDescription: String? {
        switch self {
        case .alreadyListening:
            return "Speech recognition is already active"

        case .audioSessionInterrupted:
            return "Audio session was interrupted"

        case .audioSessionSetupFailed(let error):
            return "Failed to set up audio session: \(error.localizedDescription)"

        case .authorizationDenied:
            return "Speech recognition permission was denied"

        case .microphonePermissionDenied:
            return "Microphone permission was denied"

        case .noSpeechDetected:
            return "No speech was detected"

        case .recognitionCancelled:
            return "Speech recognition was cancelled"

        case .recognitionFailed(let error):
            return "Speech recognition failed: \(error.localizedDescription)"

        case .recognizerUnavailable:
            return "Speech recognition is not available on this device"
        }
    }
}
