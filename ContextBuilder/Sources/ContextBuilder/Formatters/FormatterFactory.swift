import Abstractions
import Foundation
import OSLog

/// Factory for creating context formatters based on model architecture
internal enum FormatterFactory {
    private static let logger: Logger = Logger(
        subsystem: "ContextBuilder",
        category: "FormatterFactory"
    )

    internal static func createFormatter(for model: SendableModel) throws -> ContextFormatter {
        let labels: any StopSequenceLabels = try LabelFactory.createLabels(for: model.architecture)

        switch model.architecture {
        case .harmony, .gpt, .unknown:
            return try createHarmonyFormatter(labels: labels, architecture: model.architecture)

        case .qwen:
            return try createQwenFormatter(labels: labels, architecture: model.architecture)

        case .llama:
            return try createLlamaFormatter(labels: labels, architecture: model.architecture)

        case .mistral, .mixtral:
            return try createMistralFormatter(labels: labels, architecture: model.architecture)

        case .yi, .smol, .gemma, .deepseek, .chatglm, .phi, .phi4, .falcon, .baichuan:
            return try createChatMLFormatter(labels: labels, architecture: model.architecture)

        default:
            logger.error("Unsupported architecture: \(model.architecture.rawValue)")
            throw LabelError.unsupportedArchitecture(model.architecture)
        }
    }

    private static func createHarmonyFormatter(
        labels: any StopSequenceLabels,
        architecture: Architecture
    ) throws -> ContextFormatter {
        guard let harmonyLabels = labels as? HarmonyLabels else {
            throw LabelError.unsupportedArchitecture(architecture)
        }
        return HarmonyContextFormatter(labels: harmonyLabels)
    }

    private static func createQwenFormatter(
        labels: any StopSequenceLabels,
        architecture: Architecture
    ) throws -> ContextFormatter {
        guard let qwenLabels = labels as? QwenLabels else {
            throw LabelError.unsupportedArchitecture(architecture)
        }
        return QwenContextFormatter(labels: qwenLabels)
    }

    private static func createLlamaFormatter(
        labels: any StopSequenceLabels,
        architecture: Architecture
    ) throws -> ContextFormatter {
        guard let llamaLabels = labels as? Llama3Labels else {
            throw LabelError.unsupportedArchitecture(architecture)
        }
        return Llama3ContextFormatter(labels: llamaLabels)
    }

    private static func createMistralFormatter(
        labels: any StopSequenceLabels,
        architecture: Architecture
    ) throws -> ContextFormatter {
        guard let mistralLabels = labels as? MistralLabels else {
            throw LabelError.unsupportedArchitecture(architecture)
        }
        return MistralContextFormatter(labels: mistralLabels)
    }

    private static func createChatMLFormatter(
        labels: any StopSequenceLabels,
        architecture: Architecture
    ) throws -> ContextFormatter {
        guard let chatmlLabels = labels as? ChatMLLabels else {
            throw LabelError.unsupportedArchitecture(architecture)
        }
        return ChatMLContextFormatter(labels: chatmlLabels)
    }
}
