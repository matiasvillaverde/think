import AVFoundation
import Foundation
import os.log

// MARK: - State Management and Cleanup
extension SpeechRecognizer {
    /// Removes notification observers
    func removeNotificationObservers() {
        #if os(iOS) || os(tvOS) || os(watchOS)
        if let routeChangeObserver {
            NotificationCenter.default.removeObserver(routeChangeObserver)
            self.routeChangeObserver = nil
        }

        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        #endif
    }

    /// Completely resets the recognizer state
    func resetState() {
        logger.debug("Resetting state")

        // Reset transcript and state variables
        currentTranscript = ""
        state = .idle
        hasReceivedAudio = false
        lastAudioTimestamp = Date()
        currentAudioLevel = 0
    }

    /// Cleans up all resources used for recognition
    func cleanupResources() {
        logger.debug("Cleaning up resources")

        // Cancel silence detection task
        silenceTask?.cancel()
        silenceTask = nil

        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Stop audio engine
        if let inputNode = audioEngine?.inputNode {
            inputNode.removeTap(onBus: 0)
        }
        audioEngine?.stop()
        audioEngine = nil

        // Clean up request
        recognitionRequest = nil

        // Deactivate audio session to release it for other audio components
        deactivateAudioSession()
    }
}
