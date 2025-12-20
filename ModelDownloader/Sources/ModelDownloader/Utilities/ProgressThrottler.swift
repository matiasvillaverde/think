import Foundation

/// Manages progress update throttling to prevent UI overload
/// 
/// This actor ensures that progress updates are throttled to prevent
/// excessive UI updates while always allowing important updates
/// (0%, 100%, significant changes) to go through immediately.
public actor ProgressThrottler <ID: Hashable & Sendable> {
    // MARK: - Types

    private struct ProgressState {
        var lastUpdateTime: Date
        var lastProgress: Double
    }

    // MARK: - Properties

    /// The minimum interval between updates (in seconds)
    private let throttleInterval: TimeInterval

    /// Tracks the last update time and progress for each ID
    private var progressStates: [ID: ProgressState] = [:]

    /// The minimum progress change to force an update (1%)
    private let significantChangeThreshold: Double = 0.01

    // MARK: - Initialization

    /// Initialize with a throttle interval
    /// - Parameter throttleInterval: Minimum seconds between updates (default: 0.5)
    public init(throttleInterval: TimeInterval = 0.5) {
        self.throttleInterval = throttleInterval
    }

    // MARK: - Public Methods

    /// Determines if a progress update should be shown
    /// - Parameters:
    ///   - id: The identifier for this progress tracking
    ///   - progress: The current progress value (0.0 to 1.0)
    /// - Returns: true if the update should be shown, false if it should be throttled
    public func shouldUpdate(id: ID, progress: Double) -> Bool {
        // Always update on 0% and 100%
        if progress == 0.0 || progress == 1.0 {
            updateState(id: id, progress: progress)
            return true
        }

        // Check if this is the first update for this ID
        guard let state = progressStates[id] else {
            // First update always goes through
            updateState(id: id, progress: progress)
            return true
        }

        // Check if enough time has passed
        let timeSinceLastUpdate: TimeInterval = Date().timeIntervalSince(state.lastUpdateTime)
        if timeSinceLastUpdate >= throttleInterval {
            updateState(id: id, progress: progress)
            return true
        }

        // Check if the progress change is significant
        let progressChange: Double = abs(progress - state.lastProgress)
        if progressChange >= significantChangeThreshold {
            updateState(id: id, progress: progress)
            return true
        }

        // Otherwise, throttle this update
        return false
    }

    /// Cleans up tracking data for a specific ID
    /// - Parameter id: The identifier to clean up
    public func cleanup(id: ID) {
        progressStates.removeValue(forKey: id)
    }

    /// Resets the tracking for a specific ID, allowing immediate update
    /// - Parameter id: The identifier to reset
    public func reset(id: ID) {
        progressStates.removeValue(forKey: id)
    }

    // MARK: - Private Methods

    /// Updates the state for a given ID
    private func updateState(id: ID, progress: Double) {
        progressStates[id] = ProgressState(
            lastUpdateTime: Date(),
            lastProgress: progress
        )
    }
}
