import Foundation

/// Protocol defining the public interface for managing review prompts
public protocol ReviewPromptManaging: Actor {
    /// Record that a positive action has occurred
    func recordPositiveAction() async

    /// Check if we should ask for a review
    @MainActor var shouldAskForReview: Bool { get }

    /// Record that a review has been requested
    func reviewRequested() async

    /// Record that the user chose to be asked later, resetting the counter and doubling the threshold
    func userRequestedLater() async
}
