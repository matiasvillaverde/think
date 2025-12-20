import Abstractions
import Foundation
import OSLog

/// Coordinator that manages steering requests during generation
internal actor SteeringCoordinator {
    private static let logger: Logger = Logger(
        subsystem: AgentOrchestratorConfiguration.shared.logging.subsystem,
        category: "SteeringCoordinator"
    )

    /// The current pending steering request
    private var pendingRequest: SteeringRequest?

    /// Whether steering is currently active
    internal var hasPendingRequest: Bool {
        pendingRequest != nil
    }

    /// Get the current pending request
    internal var currentRequest: SteeringRequest? {
        pendingRequest
    }

    /// Submit a new steering request
    /// - Parameter mode: The steering mode to apply
    /// - Returns: The created steering request
    @discardableResult
    internal func submit(mode: SteeringMode) -> SteeringRequest {
        let request: SteeringRequest = SteeringRequest(mode: mode)
        pendingRequest = request
        Self.logger.info("Steering request submitted: \(String(describing: mode))")
        return request
    }

    /// Consume and clear the pending request
    /// - Returns: The pending request if one exists
    internal func consume() -> SteeringRequest? {
        guard let request = pendingRequest else {
            return nil
        }
        pendingRequest = nil
        Self.logger.info("Steering request consumed: \(request.id)")
        return request
    }

    /// Clear any pending steering request
    internal func clear() {
        if pendingRequest != nil {
            Self.logger.info("Steering request cleared")
            pendingRequest = nil
        }
    }

    /// Check if steering should interrupt current operation
    /// - Returns: True if a hard stop is requested
    internal func shouldInterruptImmediately() -> Bool {
        guard let request = pendingRequest else {
            return false
        }
        return request.mode == .hardStop
    }

    /// Check if steering should skip remaining tools
    /// - Returns: True if tools should be skipped
    internal func shouldSkipRemainingTools() -> Bool {
        guard let request = pendingRequest else {
            return false
        }
        switch request.mode {
        case .hardStop, .redirect:
            return true

        case .softInterrupt, .inactive:
            return false
        }
    }
}
