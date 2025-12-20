import Abstractions
import Foundation

/// Errors that can occur during label creation and configuration
public enum LabelError: LocalizedError, CustomStringConvertible, Sendable, Equatable {
    /// Configuration is missing required parameters
    case invalidConfiguration(reason: String)

    /// The model type cannot be used for chat/conversation tasks
    case nonConversationalModel(modelType: String)

    /// The specified architecture is not supported for conversational AI
    case unsupportedArchitecture(Architecture)

    /// The requested label variant is not available
    case variantNotAvailable(architecture: Architecture, variant: String)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .unsupportedArchitecture(let architecture):
            return String(
                localized: "LabelError.UnsupportedArchitecture.Description",
                defaultValue: "Architecture '\(architecture.rawValue)' is not supported for chat.",
                bundle: .module
            )

        case .nonConversationalModel(let modelType):
            return String(
                localized: "LabelError.NonConversationalModel.Description",
                defaultValue: "Model '\(modelType)' cannot be used for chat.",
                bundle: .module
            )

        case let .variantNotAvailable(architecture, variant):
            return String(
                localized: "LabelError.VariantNotAvailable.Description",
                defaultValue: "Variant '\(variant)' not available for \(architecture.rawValue).",
                bundle: .module
            )

        case .invalidConfiguration(let reason):
            return String(
                localized: "LabelError.InvalidConfiguration.Description",
                defaultValue: "Invalid label configuration: \(reason)",
                bundle: .module
            )
        }
    }

    public var failureReason: String? {
        switch self {
        case .unsupportedArchitecture(let architecture):
            return String(
                localized: "LabelError.UnsupportedArchitecture.Reason",
                defaultValue: "\(architecture.rawValue) models don't support chat formatting.",
                bundle: .module
            )

        case .nonConversationalModel(let modelType):
            return String(
                localized: "LabelError.NonConversationalModel.Reason",
                defaultValue: "\(modelType) is a specialized model without chat capabilities.",
                bundle: .module
            )

        case .variantNotAvailable:
            return String(
                localized: "LabelError.VariantNotAvailable.Reason",
                defaultValue: "The requested variant does not exist.",
                bundle: .module
            )

        case .invalidConfiguration:
            return String(
                localized: "LabelError.InvalidConfiguration.Reason",
                defaultValue: "Required configuration parameters are missing or invalid.",
                bundle: .module
            )
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unsupportedArchitecture:
            return String(
                localized: "LabelError.UnsupportedArchitecture.Recovery",
                defaultValue: "Use Llama, Mistral, Qwen, or GPT for chat.",
                bundle: .module
            )

        case .nonConversationalModel:
            return String(
                localized: "LabelError.NonConversationalModel.Recovery",
                defaultValue: "Select a model designed for chat or conversation tasks.",
                bundle: .module
            )

        case .variantNotAvailable(let architecture, _):
            return String(
                localized: "LabelError.VariantNotAvailable.Recovery",
                defaultValue: "Use default config for \(architecture.rawValue).",
                bundle: .module
            )

        case .invalidConfiguration:
            return String(
                localized: "LabelError.InvalidConfiguration.Recovery",
                defaultValue: "Verify all required configuration parameters are provided.",
                bundle: .module
            )
        }
    }

    public var helpAnchor: String? {
        switch self {
        case .unsupportedArchitecture:
            return "label-unsupported-architecture"

        case .nonConversationalModel:
            return "label-non-conversational"

        case .variantNotAvailable:
            return "label-variant-unavailable"

        case .invalidConfiguration:
            return "label-invalid-config"
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

    // MARK: - Private Helpers

    private func modelPurpose(for architectureOrType: String) -> String {
        switch architectureOrType.lowercased() {
        case "bert":
            return String(
                localized: "LabelError.ModelPurpose.BERT",
                defaultValue: "text embeddings and classification",
                bundle: .module
            )

        case "t5":
            return String(
                localized: "LabelError.ModelPurpose.T5",
                defaultValue: "text-to-text transformation",
                bundle: .module
            )

        case "stablediffusion", "stable-diffusion", "stable_diffusion":
            return String(
                localized: "LabelError.ModelPurpose.StableDiffusion",
                defaultValue: "image generation from text",
                bundle: .module
            )

        case "flux":
            return String(
                localized: "LabelError.ModelPurpose.Flux",
                defaultValue: "advanced image generation",
                bundle: .module
            )

        case "whisper":
            return String(
                localized: "LabelError.ModelPurpose.Whisper",
                defaultValue: "speech-to-text transcription",
                bundle: .module
            )

        default:
            return String(
                localized: "LabelError.ModelPurpose.Unknown",
                defaultValue: "specialized non-conversational tasks",
                bundle: .module
            )
        }
    }
    // MARK: - Equatable Implementation

    /// Compares two LabelError instances for equality
    /// - Parameters:
    ///   - lhs: The left-hand side error
    ///   - rhs: The right-hand side error
    /// - Returns: true if the errors are equal
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.invalidConfiguration(lhsReason), .invalidConfiguration(rhsReason)):
            return lhsReason == rhsReason

        case let (.nonConversationalModel(lhsType), .nonConversationalModel(rhsType)):
            return lhsType == rhsType

        case let (.unsupportedArchitecture(lhsArch), .unsupportedArchitecture(rhsArch)):
            return lhsArch == rhsArch

        case let (.variantNotAvailable(lhsArch, lhsVariant),
            .variantNotAvailable(rhsArch, rhsVariant)):
            return lhsArch == rhsArch && lhsVariant == rhsVariant

        default:
            return false
        }
    }
}
