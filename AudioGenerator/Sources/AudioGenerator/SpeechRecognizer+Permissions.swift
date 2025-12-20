import AVFoundation
import Foundation
import os.log
import Speech

// MARK: - Permission Management
extension SpeechRecognizer {
    /// Checks if we have all required permissions for speech recognition
    func checkPermissions() async throws {
        logger.debug("Checking permissions")

        // Check speech recognition authorization
        let speechAuthorized: Bool = await requestSpeechAuthorization()
        guard speechAuthorized else {
            logger.notice("Speech recognition authorization denied")
            throw RecognizerError.authorizationDenied
        }

        // Check microphone permission
        let microphoneAuthorized: Bool = await requestMicrophonePermission()
        guard microphoneAuthorized else {
            logger.notice("Microphone permission denied")
            throw RecognizerError.microphonePermissionDenied
        }

        // Check if speech recognition is available
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            logger.notice("Speech recognizer is unavailable")
            throw RecognizerError.recognizerUnavailable
        }

        logger.debug("All permissions granted")
    }

    /// Requests authorization for speech recognition
    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Requests permission to use the microphone
    private func requestMicrophonePermission() async -> Bool {
        #if os(iOS) || os(tvOS) || os(watchOS)
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
        #elseif os(macOS)
        // On macOS, check if we have an input device available
        return !AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .microphone,
                .external
            ],
            mediaType: .audio,
            position: .unspecified
        ).devices.isEmpty
        #else
        return false
        #endif
    }
}
