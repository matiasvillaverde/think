import Foundation

/// Protocol for coordinating background model downloads during onboarding
///
/// This protocol defines the interface for managing the background download of models
/// while users progress through onboarding screens, ensuring models are ready when they
/// reach the main app.
public protocol OnboardingCoordinating: Actor {
    /// Overall download progress for all models (0.0 to 1.0)
    var overallProgress: Double { get }

    /// Whether all model downloads are complete
    var isDownloadComplete: Bool { get }
}
