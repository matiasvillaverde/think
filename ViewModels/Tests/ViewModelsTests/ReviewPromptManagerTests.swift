// swiftlint:disable line_length
import Abstractions
import AbstractionsTestUtilities
import Combine
import Foundation
import Testing
@testable import ViewModels
import XCTest

@Suite(.tags(.acceptance), .serialized)
internal struct ReviewPromptManagerTests {
    @Test("Review prompt manager correctly tracks positive actions and prompts for review")
    func reviewPromptTrackingAndPrompting() async throws {
        // Create the review prompt manager
        let reviewManager: ReviewPromptViewModel = ReviewPromptViewModel(userDefaults: UserDefaults.standard)

        // Reset all values to ensure clean state
        await reviewManager.resetAllValues()

        // Verify we start with shouldAskForReview = false
        #expect(await reviewManager.shouldAskForReview == false)

        // When - Record positive actions but not enough to trigger a review
        for _ in 1...14 {
            await reviewManager.recordPositiveAction()
        }

        // Then - Still should not ask for review (only 4 actions, threshold is 5)
        #expect(await reviewManager.shouldAskForReview == false)

        // When - Record one more positive action to reach the threshold
        await reviewManager.recordPositiveAction()

        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Then - Should now ask for review (5 actions)
        #expect(await reviewManager.shouldAskForReview == true)

        // When - User chooses "later"
        await reviewManager.userRequestedLater()

        // Then - Should reset and not ask for review
        #expect(await reviewManager.shouldAskForReview == false)

        // Verify threshold was doubled (now need 10 actions)
        #expect(UserDefaults.standard.integer(forKey: "com.app.thresholdMultiplier") == 2)

        // When - Record 14 more positive actions (not enough for doubled threshold)
        for _ in 1...29 {
            await reviewManager.recordPositiveAction()
        }

        // Then - Still should not ask for review
        #expect(await reviewManager.shouldAskForReview == false)

        // When - Record one more positive action to reach the doubled threshold
        await reviewManager.recordPositiveAction()

        // Then - Should now ask for review again (10 actions with 2x multiplier)
        #expect(await reviewManager.shouldAskForReview == true)

        // When - User agrees to review
        await reviewManager.reviewRequested()

        // Then - Should reset everything
        #expect(await reviewManager.shouldAskForReview == false)
        #expect(UserDefaults.standard.integer(forKey: "com.app.positiveActionCount") == 0)
        #expect(UserDefaults.standard.integer(forKey: "com.app.thresholdMultiplier") == 1)

        // Verify we recorded the current version
        let currentVersion: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        #expect(UserDefaults.standard.string(forKey: "com.app.lastReviewVersion") == currentVersion)

        // When - Try to record more positive actions after reviewing for this version
        for _ in 1...10 {
            await reviewManager.recordPositiveAction()
        }

        // Then - Should still not ask for review (already asked for this version)
        #expect(await reviewManager.shouldAskForReview == false)

        // Restore original UserDefaults
        await reviewManager.resetAllValues()
    }
}
// swiftlint:enable line_length
