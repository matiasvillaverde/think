import Abstractions
import Foundation

/// Errors that can occur during context building
public enum ContextBuilderError: LocalizedError, CustomStringConvertible, Sendable, Equatable {
    /// Context would exceed maximum token limit
    case contextTooLarge(estimatedTokens: Int, maxTokens: Int)

    /// Tooling implementation is unavailable
    case toolingUnavailable

    /// Requested tools are not available in the tooling implementation
    case toolsNotAvailable(requested: Set<ToolIdentifier>, missing: Set<ToolIdentifier>)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case let .contextTooLarge(estimated, max):
            return String(
                localized: "ContextBuilderError.ContextTooLarge.Description",
                defaultValue: "Context would be \(estimated) tokens, exceeding limit of \(max)",
                bundle: .module
            )

        case .toolingUnavailable:
            return String(
                localized: "ContextBuilderError.ToolingUnavailable.Description",
                defaultValue: "Tool system is currently unavailable",
                bundle: .module
            )

        case let .toolsNotAvailable(requested, missing):
            let requestedNames: String = requested.map(\.rawValue).sorted().joined(separator: ", ")
            let missingNames: String = missing.map(\.rawValue).sorted().joined(separator: ", ")
            return String(
                localized: "ContextBuilderError.ToolsNotAvailable.Description",
                defaultValue: "Tools [\(requestedNames)] not available. Missing: [\(missingNames)]",
                bundle: .module
            )
        }
    }

    public var failureReason: String? {
        switch self {
        case .contextTooLarge:
            return String(
                localized: "ContextBuilderError.ContextTooLarge.Reason",
                defaultValue: "The generated context exceeds the model's maximum input length",
                bundle: .module
            )

        case .toolingUnavailable:
            return String(
                localized: "ContextBuilderError.ToolingUnavailable.Reason",
                defaultValue: "The underlying tool execution system is not accessible",
                bundle: .module
            )

        case let .toolsNotAvailable(_, missing):
            let missingNames: String = missing.map(\.rawValue).sorted().joined(separator: ", ")
            return String(
                localized: "ContextBuilderError.ToolsNotAvailable.Reason",
                defaultValue: "The tooling implementation does not provide: \(missingNames)",
                bundle: .module
            )
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .contextTooLarge:
            return String(
                localized: "ContextBuilderError.ContextTooLarge.Recovery",
                defaultValue: "Reduce conversation history, system instructions, or tools",
                bundle: .module
            )

        case .toolingUnavailable:
            return String(
                localized: "ContextBuilderError.ToolingUnavailable.Recovery",
                defaultValue: "Check tool system configuration and try again",
                bundle: .module
            )

        case let .toolsNotAvailable(_, missing):
            let missingNames: String = missing.map(\.rawValue).sorted().joined(separator: ", ")
            return String(
                localized: "ContextBuilderError.ToolsNotAvailable.Recovery",
                defaultValue: "Configure tooling for: \(missingNames), or remove from request",
                bundle: .module
            )
        }
    }

    public var helpAnchor: String? {
        switch self {
        case .contextTooLarge:
            return "context-too-large"

        case .toolingUnavailable:
            return "context-tooling-unavailable"

        case .toolsNotAvailable:
            return "context-tools-not-available"
        }
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        var components: [String] = []

        if let description = errorDescription {
            components.append(description)
        }

        if let reason = failureReason {
            components.append("Reason: \(reason)")
        }

        if let recovery = recoverySuggestion {
            components.append("Suggestion: \(recovery)")
        }

        return components.joined(separator: " ")
    }

    // MARK: - Equatable

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.contextTooLarge(lhsEstimated, lhsMax), .contextTooLarge(rhsEstimated, rhsMax)):
            return lhsEstimated == rhsEstimated && lhsMax == rhsMax

        case (.toolingUnavailable, .toolingUnavailable):
            return true

        case let (
            .toolsNotAvailable(lhsRequested, lhsMissing),
            .toolsNotAvailable(rhsRequested, rhsMissing)
        ):
            return lhsRequested == rhsRequested && lhsMissing == rhsMissing

        default:
            return false
        }
    }
}
