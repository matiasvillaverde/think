import Testing
@testable import Abstractions

@Suite("AppFlowState Tests")
struct AppFlowStateTests {
    @Test("AppFlowState should have correct cases")
    func testAppFlowStateCases() {
        // Test that all expected cases exist
        _ = AppFlowState.onboardingWelcome
        _ = AppFlowState.onboardingFeatures
        _ = AppFlowState.welcomeModelSelection
        _ = AppFlowState.mainApp
    }

    @Test("AppFlowState should be Equatable")
    func testAppFlowStateEquatable() {
        // Test that each case equals itself
        let onboardingWelcome = AppFlowState.onboardingWelcome
        let onboardingFeatures = AppFlowState.onboardingFeatures
        let welcomeModelSelection = AppFlowState.welcomeModelSelection
        let mainApp = AppFlowState.mainApp

        #expect(onboardingWelcome == AppFlowState.onboardingWelcome)
        #expect(onboardingFeatures == AppFlowState.onboardingFeatures)
        #expect(welcomeModelSelection == AppFlowState.welcomeModelSelection)
        #expect(mainApp == AppFlowState.mainApp)

        #expect(AppFlowState.onboardingWelcome != AppFlowState.onboardingFeatures)
        #expect(AppFlowState.onboardingFeatures != AppFlowState.welcomeModelSelection)
        #expect(AppFlowState.welcomeModelSelection != AppFlowState.mainApp)
    }

    @Test("AppFlowState should be Sendable")
    func testAppFlowStateSendable() async {
        // This test verifies that AppFlowState can be used across actor boundaries
        let state = AppFlowState.onboardingWelcome

        await withTaskGroup(of: AppFlowState.self) { group in
            group.addTask {
                state
            }

            for await result in group {
                #expect(result == AppFlowState.onboardingWelcome)
            }
        }
    }

    @Test("AppFlowState should provide navigation flow helpers")
    func testNavigationHelpers() {
        // Test next state transitions
        #expect(AppFlowState.onboardingWelcome.nextState == .onboardingFeatures)
        #expect(AppFlowState.onboardingFeatures.nextState == .welcomeModelSelection)
        #expect(AppFlowState.welcomeModelSelection.nextState == .mainApp)
        #expect(AppFlowState.mainApp.nextState == nil)

        // Test if onboarding is required
        #expect(AppFlowState.onboardingWelcome.isOnboarding == true)
        #expect(AppFlowState.onboardingFeatures.isOnboarding == true)
        #expect(AppFlowState.welcomeModelSelection.isOnboarding == false)
        #expect(AppFlowState.mainApp.isOnboarding == false)
    }
}
