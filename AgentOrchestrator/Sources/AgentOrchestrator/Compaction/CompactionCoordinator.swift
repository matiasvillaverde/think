import Abstractions
import Foundation
import OSLog

/// Coordinator for managing context compaction and memory flush
internal actor CompactionCoordinator {
    private static let logger: Logger = Logger(
        subsystem: AgentOrchestratorConfiguration.shared.logging.subsystem,
        category: "CompactionCoordinator"
    )

    private let config: AgentOrchestratorConfiguration.Compaction

    internal init(config: AgentOrchestratorConfiguration.Compaction = .init()) {
        self.config = config
    }

    /// Calculate context utilization based on current and maximum tokens
    /// - Parameters:
    ///   - currentTokens: Current number of tokens in context
    ///   - maxTokens: Maximum allowed tokens
    /// - Returns: Utilization percentage (0.0 to 1.0)
    internal func calculateUtilization(currentTokens: Int, maxTokens: Int) -> Double {
        guard maxTokens > 0 else {
            return 0.0
        }
        return Double(currentTokens) / Double(maxTokens)
    }

    /// Check if context utilization exceeds soft threshold
    /// - Parameter utilization: Current utilization (0.0 to 1.0)
    /// - Returns: True if memory flush should be triggered
    internal func shouldTriggerMemoryFlush(utilization: Double) -> Bool {
        guard config.enableAutoFlush else {
            return false
        }
        return utilization >= config.softThresholdPercent
    }

    /// Check if context utilization exceeds hard threshold
    /// - Parameter utilization: Current utilization (0.0 to 1.0)
    /// - Returns: True if compaction should be forced
    internal func shouldForceCompaction(utilization: Double) -> Bool {
        utilization >= config.hardThresholdPercent
    }

    /// Get the memory flush prompt
    internal var flushPrompt: String {
        config.flushPrompt
    }

    /// Check if auto-flush is enabled
    internal var isAutoFlushEnabled: Bool {
        config.enableAutoFlush
    }
}
