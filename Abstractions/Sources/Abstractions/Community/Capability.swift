import Foundation

/// Model capabilities for AI systems
///
/// Represents the various input, output, and processing capabilities that AI models
/// can support. This enum provides a structured way to describe what a model can do,
/// enabling better model selection and user interface adaptation.
///
/// ## Capability Categories
/// - **Input**: Text, image, audio, video processing
/// - **Output**: Text, image, audio generation
/// - **Processing**: Reasoning, coding, mathematics, tool use
/// - **Legacy**: Backward compatibility with older capability definitions
///
/// ## Usage
/// ```swift
/// let capabilities: Set<Capability> = [.textInput, .textOutput, .reasoning, .coding]
/// 
/// // Check for multimodal support
/// if Capability.isMultimodal(capabilities) {
///     print("This model supports multiple input types")
/// }
/// 
/// // Modernize legacy capabilities
/// let legacy: Set<Capability> = [.textGeneration, .vision]
/// let modern = Capability.modernize(legacy) // [.textInput, .textOutput, .imageInput]
/// ```
public enum Capability: String, Codable, Sendable, CaseIterable {
    // MARK: - Input Capabilities

    /// Can process text input (prompts, documents, conversations)
    case textInput = "text-input"

    /// Can process image input (photos, diagrams, charts)
    case imageInput = "image-input"

    /// Can process audio input (speech, music, sounds)
    case audioInput = "audio-input"

    /// Can process video input (clips, streams, animations)
    case videoInput = "video-input"

    // MARK: - Output Capabilities

    /// Can generate text output (responses, documents, code)
    case textOutput = "text-output"

    /// Can generate image output (photos, art, diagrams)
    case imageOutput = "image-output"

    /// Can generate audio output (speech, music, sounds)
    case audioOutput = "audio-output"

    // MARK: - Processing Capabilities

    /// Can follow complex instructions and maintain context
    case instructFollowing = "instruct-following"

    /// Can perform logical reasoning and problem-solving
    case reasoning = "reasoning"

    /// Can write, debug, and explain code
    case coding = "coding"

    /// Can solve mathematical problems and equations
    case mathematics = "mathematics"

    /// Can use external tools and APIs
    case toolUse = "tool-use"

    /// Can handle very long context windows (>32k tokens)
    case longContext = "long-context"

    /// Supports multiple languages effectively
    case multilingualSupport = "multilingual"

    // MARK: - Legacy Capabilities (Backward Compatibility)

    /// Legacy: Maps to textInput + textOutput
    case textGeneration = "text-generation"

    /// Legacy: Maps to textInput + imageOutput
    case imageGeneration = "image-generation"

    /// Legacy: Maps to audioInput + textOutput
    case audioTranscription = "audio-transcription"

    /// Legacy: Deprecated - use specific input/output capabilities
    case multimodal = "multimodal"

    /// Legacy: Deprecated - use imageInput instead
    case vision = "vision"

    /// Human-readable display name for the capability
    ///
    /// Returns a localized display name when available, falling back to
    /// computed display name for consistent presentation.
    public var displayName: String {
        // For now, use computed display name to avoid dynamic NSLocalizedString keys
        // TODO: Add proper localization with static keys for each capability
        computedDisplayName
    }

    /// Computed display name (fallback when localization not available)
    private var computedDisplayName: String {
        switch self {
        // Input capabilities
        case .textInput: return "Text Input"
        case .imageInput: return "Image Input"
        case .audioInput: return "Audio Input"
        case .videoInput: return "Video Input"

        // Output capabilities
        case .textOutput: return "Text Output"
        case .imageOutput: return "Image Output"
        case .audioOutput: return "Audio Output"

        // Processing capabilities
        case .instructFollowing: return "Instruction Following"
        case .reasoning: return "Reasoning"
        case .coding: return "Coding"
        case .mathematics: return "Mathematics"
        case .toolUse: return "Tool Use"
        case .longContext: return "Long Context"
        case .multilingualSupport: return "Multilingual"

        // Legacy capabilities
        case .textGeneration: return "Text Generation"
        case .imageGeneration: return "Image Generation"
        case .audioTranscription: return "Audio Transcription"
        case .multimodal: return "Multimodal"
        case .vision: return "Vision"
        }
    }

    /// SF Symbols icon name for the capability
    public var iconName: String {
        switch self {
        // Input capabilities
        case .textInput: return "text.cursor"
        case .imageInput: return "photo.fill"
        case .audioInput: return "mic.fill"
        case .videoInput: return "video.fill"

        // Output capabilities
        case .textOutput: return "text.alignleft"
        case .imageOutput: return "photo"
        case .audioOutput: return "speaker.wave.2"

        // Processing capabilities
        case .instructFollowing: return "checkmark.circle"
        case .reasoning: return "brain"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .mathematics: return "sum"
        case .toolUse: return "wrench.and.screwdriver"
        case .longContext: return "doc.text"
        case .multilingualSupport: return "globe"

        // Legacy capabilities
        case .textGeneration: return "text.alignleft"
        case .imageGeneration: return "photo"
        case .audioTranscription: return "waveform"
        case .multimodal: return "square.grid.2x2"
        case .vision: return "eye"
        }
    }
}

// MARK: - Capability Analysis

public extension Capability {
    /// Check if this is an input capability
    var isInput: Bool {
        switch self {
        case .textInput, .imageInput, .audioInput, .videoInput:
            return true
        default:
            return false
        }
    }

    /// Check if this is an output capability
    var isOutput: Bool {
        switch self {
        case .textOutput, .imageOutput, .audioOutput:
            return true
        default:
            return false
        }
    }

    /// Check if this is a processing capability
    var isProcessing: Bool {
        switch self {
        case .instructFollowing, .reasoning, .coding, .mathematics,
             .toolUse, .longContext, .multilingualSupport:
            return true
        default:
            return false
        }
    }

    /// Check if capabilities indicate multimodal model
    /// - Parameter capabilities: Set of capabilities to analyze
    /// - Returns: True if model supports non-text inputs
    static func isMultimodal(_ capabilities: Set<Capability>) -> Bool {
        let nonTextInputs = capabilities.filter { cap in
            [.imageInput, .audioInput, .videoInput].contains(cap)
        }
        return !nonTextInputs.isEmpty
    }

    /// Convert legacy capabilities to modern input/output capabilities
    ///
    /// Transforms deprecated capability names into their modern equivalents
    /// for consistent capability representation across the system.
    ///
    /// - Parameter capabilities: Set of capabilities to modernize
    /// - Returns: Set with legacy capabilities replaced by modern equivalents
    static func modernize(_ capabilities: Set<Capability>) -> Set<Capability> {
        var modern = Set<Capability>()

        for capability in capabilities {
            switch capability {
            case .textGeneration:
                modern.insert(.textInput)
                modern.insert(.textOutput)
            case .imageGeneration:
                modern.insert(.textInput)
                modern.insert(.imageOutput)
            case .audioTranscription:
                modern.insert(.audioInput)
                modern.insert(.textOutput)
            case .vision:
                modern.insert(.imageInput)
            case .multimodal:
                // Don't add anything - too vague
                break
            default:
                modern.insert(capability)
            }
        }

        return modern
    }
}
