import Foundation

/// Supported output formats for parsing LLM responses
internal enum OutputFormat: String, Sendable {
    case chatml = "chatml_format"
    case harmony = "harmony_format"
    case kimi = "kimi_format"
    case unknown = "unknown_format"
}
