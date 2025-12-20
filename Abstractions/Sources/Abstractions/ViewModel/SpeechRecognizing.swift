import Foundation

/// Protocol defining the interface for speech recognition capabilities
public protocol SpeechRecognizing: Actor {
    func startListening() async throws -> String
    func stopListening() async -> String
}
