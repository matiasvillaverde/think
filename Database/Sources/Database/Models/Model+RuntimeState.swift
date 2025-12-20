import Foundation

// MARK: - Runtime State Machine
extension Model {
    /// Runtime states for model lifecycle management
    public enum RuntimeState: Sendable, Equatable, Codable {
        case notLoaded
        case loading
        case loaded
        case generating
        case error
    }

    /// Valid runtime state transitions
    public enum RuntimeTransition: Sendable, Equatable {
        case load
        case completeLoad
        case failLoad
        case startGeneration
        case stopGeneration
        case unload
        case reset
    }
}

// MARK: - RuntimeState Convenience
extension Model.RuntimeState {
    public var isOperational: Bool {
        switch self {
        case .loaded, .generating:
            return true
        default:
            return false
        }
    }

    public var canGenerate: Bool {
        self == .loaded
    }

    public var isTransitioning: Bool {
        self == .loading
    }
}

// MARK: - Runtime State Management
extension Model {
    /// Safely transition the runtime state using the state machine
    internal func transitionRuntimeState(_ transition: RuntimeTransition) -> RuntimeState? {
        if let newState = Self.nextRuntimeState(from: runtimeState ?? .notLoaded, via: transition) {
            runtimeState = newState
            return newState
        }
        return nil
    }

    /// Pure function for runtime state transitions
    private static func nextRuntimeState(from state: RuntimeState, via transition: RuntimeTransition) -> RuntimeState? {
        switch (state, transition) {
        // From notLoaded
        case (.notLoaded, .load):
            return .loading

        // From loading
        case (.loading, .completeLoad):
            return .loaded
        case (.loading, .failLoad):
            return .error
        case (.loading, .unload):
            return .notLoaded

        // From loaded
        case (.loaded, .startGeneration):
            return .generating
        case (.loaded, .unload):
            return .notLoaded

        // From generating
        case (.generating, .stopGeneration):
            return .loaded
        case (.generating, .unload):
            return .notLoaded

        // From error
        case (.error, .reset):
            return .notLoaded
        case (.error, .load):
            return .loading

        // From any state - force reset
        case (_, .reset):
            return .notLoaded

        default:
            return nil // Invalid transition
        }
    }

    /// Check if a transition is valid without applying it
    internal func canTransitionRuntimeState(_ transition: RuntimeTransition) -> Bool {
        Self.nextRuntimeState(from: runtimeState ?? .notLoaded, via: transition) != nil
    }

    /// Reset runtime state to notLoaded (for app initialization)
    internal func resetRuntimeState() {
        runtimeState = .notLoaded
    }
}
