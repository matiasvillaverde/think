import Abstractions
import Combine
import Foundation

/// Manager for tracking positive actions and determining when to prompt for app reviews
public actor ReviewPromptViewModel: ReviewPromptManaging {
    // MARK: - Constants

    /// Multiplier for threshold doubling when user selects "later"
    private static let thresholdDoubleMultiplier: Int = 2

    /// Key for storing the positive action count in UserDefaults
    private let positiveActionCountKey: String = "com.app.positiveActionCount"

    /// Key for storing the version when a review was last requested
    private let lastReviewVersionKey: String = "com.app.lastReviewVersion"

    /// Key for storing the threshold multiplier (doubles when user selects "later")
    private let thresholdMultiplierKey: String = "com.app.thresholdMultiplier"

    // MARK: - Properties

    /// Default threshold of positive actions before asking for review
    private let defaultThreshold: Int = 15

    /// Current app version
    private let appVersion: String

    /// UserDefaults instance for persistence
    private let userDefaults: UserDefaults

    // MARK: - Initialization

    /// Initialize the review prompt manager
    /// - Parameter userDefaults: UserDefaults instance to use (defaults to standard)
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // Get current app version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            self.appVersion = version
        } else {
            self.appVersion = "unknown"
        }

        // Don't ask if we've already asked for this version
        let lastReviewVersion: String = userDefaults.string(forKey: lastReviewVersionKey) ?? ""
        if lastReviewVersion == appVersion {
            Task { @MainActor in
                shouldAskForReview = false
            }
        } else {
            Task { @MainActor in
                shouldAskForReview = false
            }
        }
    }

    // MARK: - Public API
    /// Returns whether the app should ask for a review based on current state
    @Published @MainActor public var shouldAskForReview: Bool = false

    private func notify() {
        // Don't ask if we've already asked for this version
        let lastReviewVersion: String = userDefaults.string(forKey: lastReviewVersionKey) ?? ""
        if lastReviewVersion == appVersion {
            Task { @MainActor in
                shouldAskForReview = false
            }
            return
        }

        // Get current values
        let count: Int = userDefaults.integer(forKey: positiveActionCountKey)
        let multiplier: Int = max(1, userDefaults.integer(forKey: thresholdMultiplierKey))

        // Calculate the current threshold
        let currentThreshold: Int = defaultThreshold * multiplier

        // Check if we've reached the threshold
        Task { @MainActor in
            shouldAskForReview = count >= currentThreshold
        }
    }

    /// Record a positive action
    public func recordPositiveAction() async {
        // Only increment if we're not already showing the prompt
        if await !shouldAskForReview {
            let currentCount: Int = userDefaults.integer(forKey: positiveActionCountKey)
            userDefaults.set(currentCount + 1, forKey: positiveActionCountKey)
            userDefaults.synchronize()
            notify()
        }
    }

    /// Record that a review has been requested
    public func reviewRequested() {
        // Store that we've asked for a review for this version
        userDefaults.set(appVersion, forKey: lastReviewVersionKey)

        // Reset the counter
        userDefaults.set(0, forKey: positiveActionCountKey)

        // Reset the threshold multiplier
        userDefaults.set(1, forKey: thresholdMultiplierKey)

        // Ensure changes are persisted immediately
        userDefaults.synchronize()

        notify()
    }

    /// Handle the user selecting "later" for the review
    public func userRequestedLater() {
        // Reset the counter
        userDefaults.set(0, forKey: positiveActionCountKey)

        // Double the threshold for next time
        let currentMultiplier: Int = max(1, userDefaults.integer(forKey: thresholdMultiplierKey))
        userDefaults.set(currentMultiplier * Self.thresholdDoubleMultiplier, forKey: thresholdMultiplierKey)

        // Ensure changes are persisted immediately
        userDefaults.synchronize()

        notify()
    }

    // MARK: - Helper Methods

    /// Reset all stored values (primarily for testing)
    public func resetAllValues() {
        userDefaults.removeObject(forKey: positiveActionCountKey)
        userDefaults.removeObject(forKey: lastReviewVersionKey)
        userDefaults.removeObject(forKey: thresholdMultiplierKey)
        userDefaults.synchronize()
    }
}
