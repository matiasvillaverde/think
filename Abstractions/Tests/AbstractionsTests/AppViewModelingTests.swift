import Foundation
import Testing
@testable import Abstractions

@Suite("AppViewModeling Protocol Tests")
struct AppViewModelingTests {
    @Test("AppViewModeling should have appFlowState property")
    func testAppFlowStateProperty() async {
        let mockViewModel = MockAppViewModel()

        // Test initial state
        let initialState = await mockViewModel.appFlowState
        #expect(initialState == .onboardingWelcome)

        // Test state update
        await mockViewModel.setAppFlowState(.mainApp)
        let updatedState = await mockViewModel.appFlowState
        #expect(updatedState == .mainApp)
    }

    @Test("AppViewModeling should have navigation methods")
    func testNavigationMethods() async {
        let mockViewModel = MockAppViewModel()

        // Test navigateToNextState
        await mockViewModel.navigateToNextState()
        var currentState = await mockViewModel.appFlowState
        #expect(currentState == .onboardingFeatures)

        await mockViewModel.navigateToNextState()
        currentState = await mockViewModel.appFlowState
        #expect(currentState == .welcomeModelSelection)

        await mockViewModel.navigateToNextState()
        currentState = await mockViewModel.appFlowState
        #expect(currentState == .mainApp)

        // Navigating from mainApp should not change state
        await mockViewModel.navigateToNextState()
        currentState = await mockViewModel.appFlowState
        #expect(currentState == .mainApp)
    }

    @Test("AppViewModeling should have completeOnboarding method")
    func testCompleteOnboarding() async {
        let mockViewModel = MockAppViewModel()

        // Start from onboarding
        await mockViewModel.setAppFlowState(.onboardingWelcome)

        // Complete onboarding should jump to main app
        await mockViewModel.completeOnboarding()
        let currentState = await mockViewModel.appFlowState
        #expect(currentState == .mainApp)
    }

    @Test("AppViewModeling should maintain existing methods")
    func testExistingMethods() async {
        let mockViewModel = MockAppViewModel()

        // Test existing methods still exist
        await mockViewModel.initializeDatabase()
        await mockViewModel.resumeBackgroundDownloads()
        await mockViewModel.requestNotificationPermissions()

        // Test setupInitialChat
        do {
            try await mockViewModel.setupInitialChat(with: UUID())
        } catch {
            // Expected for mock
        }
    }
}
