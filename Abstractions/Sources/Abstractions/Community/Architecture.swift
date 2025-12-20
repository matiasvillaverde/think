import Foundation

/// Model architecture types for AI models
///
/// Represents the underlying neural network architecture of AI models.
/// Each architecture has distinct characteristics, capabilities, and
/// optimization patterns that affect performance and use cases.
///
/// ## Architecture Categories
/// - **Language Models**: LLaMA, Mistral, Qwen, Phi, etc.
/// - **Multimodal**: CLIP, vision-language models
/// - **Image Generation**: Stable Diffusion, Flux
/// - **Audio**: Whisper for transcription
/// - **Specialized**: BERT for embeddings, T5 for text-to-text
///
/// ## Usage
/// ```swift
/// // Detect architecture from model name
/// let arch = Architecture.detect(from: "llama-2-7b-chat", tags: ["text-generation"])
/// print(arch.displayName) // "LLaMA"
/// 
/// // Detect with version information
/// let (architecture, version) = Architecture.detectWithVersion(from: "phi-3.5-mini")
/// print(architecture.displayName(version: version)) // "Phi 3.5"
/// ```
public enum Architecture: String, Codable, Sendable, CaseIterable {
    // Language Models
    case llama = "llama"
    case mistral = "mistral"
    case mixtral = "mixtral"  // Mistral MoE variant
    case phi = "phi"
    case phi4 = "phi4"
    case qwen = "qwen"
    case gemma = "gemma"
    case deepseek = "deepseek"
    case yi = "yi"
    case baichuan = "baichuan"
    case chatglm = "chatglm"
    case smol = "smol"
    case harmony = "harmony"
    case gpt = "gpt"

    // Specialized Models
    case bert = "bert"
    case t5 = "t5"
    case falcon = "falcon"

    // Image Generation
    case stableDiffusion = "stable-diffusion"
    case flux = "flux"

    // Audio
    case whisper = "whisper"

    // Unknown/Unsupported
    case unknown = "unknown"

    /// Human-readable display name for the architecture
    public var displayName: String {
        switch self {
        case .llama: return "LLaMA"
        case .mistral: return "Mistral"
        case .mixtral: return "Mixtral"
        case .phi: return "Phi"
        case .phi4: return "Phi4"
        case .qwen: return "Qwen"
        case .gemma: return "Gemma"
        case .bert: return "BERT"
        case .t5: return "T5"
        case .falcon: return "Falcon"
        case .stableDiffusion: return "Stable Diffusion"
        case .flux: return "Flux"
        case .whisper: return "Whisper"
        case .deepseek: return "DeepSeek"
        case .yi: return "Yi"
        case .baichuan: return "Baichuan"
        case .chatglm: return "ChatGLM"
        case .smol: return "SmolLM"
        case .harmony: return "GPT-OSS"
        case .gpt: return "GPT"
        case .unknown: return "Unknown"
        }
    }

    /// Localized display name for the architecture
    ///
    /// Currently returns displayName as fallback. Future versions will
    /// support proper localization with static keys for each architecture.
    public var localizedDisplayName: String {
        // For now, use displayName to avoid dynamic NSLocalizedString keys
        // TODO: Add proper localization with static keys for each architecture
        displayName
    }

    /// Display name with optional version information
    /// - Parameter version: Optional version string (e.g., "2", "3.2", "v2")
    /// - Returns: Formatted display name with version
    public func displayName(version: String?) -> String {
        guard let version else {
            return displayName
        }

        // Handle special version formatting
        let formattedVersion = version.lowercased().hasPrefix("v")
            ? version.uppercased()
            : version

        return "\(displayName) \(formattedVersion)"
    }

    /// Detect architecture from model name and optional tags
    ///
    /// Analyzes the model name and tags to determine the most likely architecture.
    /// Uses pattern matching with precedence for more specific architectures.
    ///
    /// - Parameters:
    ///   - name: Model name or identifier
    ///   - tags: Optional array of tags that might contain architecture hints
    /// - Returns: Detected architecture, or .unknown if no patterns match
    public static func detect(from name: String, tags: [String] = []) -> Architecture {
        let allContent = ([name] + tags).joined(separator: " ").lowercased()

        let architecturePatterns: [(patterns: [String], architecture: Architecture)] = [
            (["llama"], .llama),
            (["mixtral"], .mixtral),  // Check before mistral
            (["mistral"], .mistral),
            (["phi-4", "phi4"], .phi4),  // Check phi4 before phi
            (["phi"], .phi),
            (["qwen"], .qwen),
            (["gemma"], .gemma),
            (["harmony", "gpt-oss", "gpt-oss-120b", "gpt-oss-20b", "gpt"], .harmony),
            (["gpt"], .harmony),
            (["bert"], .bert),
            (["t5"], .t5),
            (["falcon"], .falcon),
            (["stable-diffusion", "sdxl"], .stableDiffusion),
            (["flux"], .flux),
            (["whisper"], .whisper),
            (["deepseek"], .deepseek),
            (["yi"], .yi),
            (["baichuan"], .baichuan),
            (["chatglm"], .chatglm),
            (["smol", "smollm"], .smol)
        ]

        for (patterns, architecture) in architecturePatterns {
            for pattern in patterns {
                if allContent.contains(pattern) {
                    return architecture
                }
            }
        }

        return .unknown
    }

    /// Detect architecture and version from model name
    ///
    /// Performs more detailed analysis to extract both architecture type
    /// and version information from the model name.
    ///
    /// - Parameters:
    ///   - name: Model name to analyze
    ///   - tags: Optional tags that might contain architecture info
    /// - Returns: Tuple of (architecture, version)
    public static func detectWithVersion(from name: String, tags: [String] = []) -> (architecture: Architecture, version: String?) {
        let lowercasedName = name.lowercased()

        // Order matters - check more specific patterns first
        let patterns: [(pattern: String, architecture: Architecture)] = [
            ("mixtral", .mixtral),  // Before mistral
            ("chatglm", .chatglm),
            ("baichuan", .baichuan),
            ("deepseek", .deepseek),
            ("mistral", .mistral),
            ("llama", .llama),
            ("gemma", .gemma),
            ("gpt-oss", .harmony),  // Check gpt-oss before gpt
            ("harmony", .harmony),
            ("qwen", .qwen),
            ("smollm", .smol),  // Check SmolLM before smol
            ("smol", .smol),
            ("phi-4", .phi4),  // Check phi-4 before phi
            ("phi4", .phi4),   // Also check phi4 variant
            ("phi", .phi),
            ("yi", .yi),
            ("gpt", .harmony),
            ("bert", .bert),
            ("t5", .t5),
            ("falcon", .falcon),
            ("stable-diffusion", .stableDiffusion),
            ("sdxl", .stableDiffusion),
            ("flux", .flux),
            ("whisper", .whisper)
        ]

        for (pattern, architecture) in patterns {
            if let range = lowercasedName.range(of: pattern) {
                // Extract version after the architecture name
                let afterPattern = String(lowercasedName[range.upperBound...])
                let version = extractVersion(from: afterPattern)

                return (architecture, version)
            }
        }

        // Check tags as fallback
        let allContent = (tags + [name]).joined(separator: " ").lowercased()
        for (pattern, architecture) in patterns {
            if allContent.contains(pattern) {
                return (architecture, nil)
            }
        }

        return (.unknown, nil)
    }

    /// Extract version number from string following architecture name
    private static func extractVersion(from string: String) -> String? {
        // Remove common separators
        let cleaned = string.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")

        // Pattern for version: optional 'v' followed by numbers and dots
        let versionPattern = #"^(v)?(\d+(?:\.\d+)*)"#

        if let regex = try? NSRegularExpression(pattern: versionPattern, options: .caseInsensitive) {
            let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            if let match = regex.firstMatch(in: cleaned, options: [], range: range) {
                // Capture group 2 has the version number
                if match.numberOfRanges > 2,
                   let versionRange = Range(match.range(at: 2), in: cleaned) {
                    var version = String(cleaned[versionRange])

                    // Add 'v' prefix back if it was there
                    if match.range(at: 1).location != NSNotFound {
                        version = "v" + version
                    }

                    return version
                }
            }
        }

        return nil
    }
}
