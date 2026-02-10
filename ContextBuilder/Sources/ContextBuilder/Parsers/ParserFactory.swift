import Abstractions
import Foundation
import OSLog

/// Factory for creating output parsers based on model architecture
internal enum ParserFactory {
    private static let logger: Logger = Logger(
        subsystem: "ContextBuilder",
        category: "ParserFactory"
    )

    internal static func createParser(
        for model: SendableModel,
        cache: ProcessingCache,
        output: String? = nil
    ) throws -> OutputParser {
        if let output {
            let detectedFormat: OutputFormat = OutputFormatDetector.detect(from: output)
            switch detectedFormat {
            case .harmony:
                return HarmonyOutputParser(labels: HarmonyLabels(), cache: cache)

            case .kimi:
                return KimiOutputParser(cache: cache)

            case .chatml:
                return ChatMLOutputParser(labels: LabelFactory.createChatMLLabels(), cache: cache)

            case .unknown:
                break
            }
        }

        let labels: any StopSequenceLabels = try LabelFactory.createLabels(for: model.architecture)

        switch model.architecture {
        case .harmony, .gpt, .unknown:
            guard let harmonyLabels = labels as? HarmonyLabels else {
                throw LabelError.unsupportedArchitecture(model.architecture)
            }
            return HarmonyOutputParser(labels: harmonyLabels, cache: cache)

        case .qwen:
            // Qwen has special labels but uses ChatML parser
            return ChatMLOutputParser(labels: LabelFactory.createQwenLabels(), cache: cache)

        case .yi, .smol, .gemma, .deepseek, .chatglm, .phi, .phi4, .falcon, .baichuan,
            .llama, .mistral, .mixtral:
            // All other architectures use ChatML parser with standard labels
            return ChatMLOutputParser(labels: LabelFactory.createChatMLLabels(), cache: cache)

        default:
            logger.error("Unsupported architecture for parser: \(model.architecture.rawValue)")
            throw LabelError.unsupportedArchitecture(model.architecture)
        }
    }
}
