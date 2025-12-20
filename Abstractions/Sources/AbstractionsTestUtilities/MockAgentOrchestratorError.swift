import Foundation

/// Custom errors for testing MockAgentOrchestrator
public enum MockAgentOrchestratorError: Error, LocalizedError {
    case loadFailed
    case unloadFailed
    case generateFailed
    case stopFailed

    public var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "Mock load failed"
        case .unloadFailed:
            return "Mock unload failed"
        case .generateFailed:
            return "Mock generate failed"
        case .stopFailed:
            return "Mock stop failed"
        }
    }
}
