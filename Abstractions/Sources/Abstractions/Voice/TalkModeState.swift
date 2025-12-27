import Foundation

/// Represents the current state of talk mode.
public enum TalkModeState: String, Sendable, Equatable {
    case idle
    case waitingForWakeWord
    case listening
    case processing
}
