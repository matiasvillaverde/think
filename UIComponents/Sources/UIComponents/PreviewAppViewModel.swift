import Abstractions
import Foundation

/// Preview implementation of AppViewModeling for SwiftUI previews
public actor PreviewAppViewModel: AppViewModeling {
    // MARK: - Properties

    private var _appFlowState: AppFlowState = .onboardingWelcome

    // MARK: - AppViewModeling Implementation

    public var appFlowState: AppFlowState {
        _appFlowState
    }

    public func initializeDatabase() {
        // Preview implementation - no-op
    }

    public func setupInitialChat(with _: UUID) {
        // Preview implementation - no-op
    }

    public func resumeBackgroundDownloads() {
        // Preview implementation - no-op
    }

    public func navigateToNextState() {
        if let nextState = _appFlowState.nextState {
            _appFlowState = nextState
        }
    }

    public func completeOnboarding() {
        _appFlowState = .mainApp
    }

    public func requestNotificationPermissions() {
        // Preview implementation - no-op
    }

    public func ensureDefaultModelExists() {
        // Preview implementation - no-op
    }

    // MARK: - Preview Helpers

    public func setAppFlowState(_ state: AppFlowState) {
        _appFlowState = state
    }
}
