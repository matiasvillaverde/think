import Foundation
@testable import Abstractions

/// Mock implementation of AppViewModeling protocol for testing
///
/// Provides a minimal actor-based implementation of the AppViewModeling protocol
/// that can be used in unit tests without requiring real dependencies or side effects.
/// All methods provide basic mock behavior suitable for testing protocol conformance
/// and state transitions.
///
/// ## Usage in Tests
/// ```swift
/// @Test func testAppFlowNavigation() async {
///     let mockViewModel = MockAppViewModel()
///     
///     await mockViewModel.navigateToNextState()
///     let state = await mockViewModel.appFlowState
///     #expect(state == .onboardingFeatures)
/// }
/// ```
actor MockAppViewModel: AppViewModeling {
    private var _appFlowState: AppFlowState = .onboardingWelcome

    /// Current application flow state
    var appFlowState: AppFlowState {
        _appFlowState
    }

    /// Set the application flow state directly
    /// - Parameter state: The new flow state to set
    func setAppFlowState(_ state: AppFlowState) {
        _appFlowState = state
    }

    /// Navigate to the next state in the onboarding flow
    ///
    /// Progresses through the standard onboarding sequence:
    /// onboardingWelcome → onboardingFeatures → welcomeModelSelection → mainApp
    func navigateToNextState() {
        if let nextState = _appFlowState.nextState {
            _appFlowState = nextState
        }
    }

    /// Complete onboarding and jump directly to main app
    func completeOnboarding() {
        _appFlowState = .mainApp
    }

    /// Mock database initialization (no-op)
    func initializeDatabase() {
        // Mock implementation - no actual database operations
    }

    /// Mock background download resumption (no-op)
    func resumeBackgroundDownloads() {
        // Mock implementation - no actual download operations
    }

    /// Mock notification permission request (no-op)
    func requestNotificationPermissions() {
        // Mock implementation - no actual permission requests
    }

    /// Mock initial chat setup (throws for testing error handling)
    /// - Parameter modelId: The model ID to set up chat with
    /// - Throws: Always throws a mock error for testing error handling
    func setupInitialChat(with modelId: UUID) throws {
        // Mock implementation - throws for testing error handling
        struct MockSetupError: Error {}
        throw MockSetupError()
    }
}
