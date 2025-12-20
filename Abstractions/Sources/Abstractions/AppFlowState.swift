import Foundation

/// Represents the different states of the application flow, including onboarding and main app states
public enum AppFlowState: Equatable, Sendable {
    /// First onboarding screen - introduces the app and its value proposition
    case onboardingWelcome

    /// Second onboarding screen - showcases key features
    case onboardingFeatures

    /// Model selection screen (existing WelcomeView)
    case welcomeModelSelection

    /// Main application interface with chat functionality
    case mainApp

    /// Returns the next state in the onboarding flow, or nil if this is the final state
    public var nextState: AppFlowState? {
        switch self {
        case .onboardingWelcome:
            return .onboardingFeatures
        case .onboardingFeatures:
            return .welcomeModelSelection
        case .welcomeModelSelection:
            return .mainApp
        case .mainApp:
            return nil
        }
    }

    /// Indicates whether this state is part of the onboarding flow
    public var isOnboarding: Bool {
        switch self {
        case .onboardingWelcome, .onboardingFeatures:
            return true
        case .welcomeModelSelection, .mainApp:
            return false
        }
    }
}
