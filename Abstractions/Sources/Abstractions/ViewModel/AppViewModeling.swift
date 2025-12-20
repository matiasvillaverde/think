import Foundation

/// Protocol defining the interface for application-wide view model operations.
///
/// This protocol establishes the contract for view models that manage
/// application lifecycle tasks such as database initialization and
/// background download resumption.
public protocol AppViewModeling: Actor {
    /// The current state of the application flow
    ///
    /// This property determines which screen should be shown to the user,
    /// managing the navigation flow from onboarding through to the main app.
    var appFlowState: AppFlowState { get async }

    /// Navigates to the next state in the application flow
    ///
    /// This method advances the app through the onboarding flow in sequence.
    /// If already at the final state (mainApp), this method has no effect.
    func navigateToNextState() async

    /// Completes the onboarding process and navigates directly to the main app
    ///
    /// This method should be called when the user has completed all onboarding
    /// requirements (terms acceptance, model selection, etc.) and is ready to
    /// use the main application.
    func completeOnboarding() async

    /// Initializes the application database.
    ///
    /// Implementations should ensure the database is properly set up
    /// for application use, handling any errors gracefully.
    func initializeDatabase() async

    /// Resumes any background downloads that were in progress when the app was terminated.
    ///
    /// This method should be called during application startup after the database
    /// has been initialized. It reconnects with downloads that were running when
    /// the app was terminated and updates their progress in the database.
    func resumeBackgroundDownloads() async

    /// Requests notification permissions for download notifications.
    ///
    /// This method should be called during application startup to ensure
    /// users receive notifications when background downloads complete.
    /// The permission request is only shown once per app installation.
    func requestNotificationPermissions() async

    /// Sets up the initial chat with the selected model.
    ///
    /// This method should be called when the user selects a model from the welcome screen.
    /// It creates the first chat using the specified model.
    ///
    /// - Parameter modelId: The UUID of the model to use for the initial chat.
    func setupInitialChat(with modelId: UUID) async throws
}
