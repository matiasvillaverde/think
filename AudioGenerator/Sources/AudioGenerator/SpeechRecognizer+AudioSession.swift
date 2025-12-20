import AVFoundation
import Foundation
import os.log

// MARK: - Audio Session Management
extension SpeechRecognizer {
    /// Sets up the audio session for recording
    func setupAudioSession() throws {
        #if os(iOS) || os(tvOS) || os(watchOS)
        let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Failed to set up audio session: \(error.localizedDescription)")
            throw RecognizerError.audioSessionSetupFailed(error)
        }
        #endif
        // On macOS, no audio session setup is needed
    }

    /// Properly deactivates the audio session when recognition is complete
    func deactivateAudioSession() {
        #if os(iOS) || os(tvOS) || os(watchOS)
        logger.debug("Deactivating audio session")

        // We need to do this on the main thread because audio session changes can affect UI
        Task { @MainActor in
            do {
                // First set the category to playback to release recording resources
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)

                // Then deactivate the session completely
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                logger.debug("Audio session successfully deactivated")
            } catch {
                logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
            }
        }
        #endif
    }
}
