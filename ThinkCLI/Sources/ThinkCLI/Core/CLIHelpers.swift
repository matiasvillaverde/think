import Abstractions
import ArgumentParser
import Foundation

enum CLIParsing {
    static func parseUUID(_ value: String, field: String) throws -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            throw ValidationError("Invalid \(field) UUID: \(value)")
        }
        return uuid
    }

    static func parseToolIdentifiers(_ rawValues: [String]) throws -> Set<ToolIdentifier> {
        guard !rawValues.isEmpty else {
            return []
        }
        var identifiers: Set<ToolIdentifier> = []
        var unknown: [String] = []

        for value in rawValues {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let match = ToolIdentifier.allCases.first(where: { identifier in
                normalized == identifier.toolName.lowercased() ||
                normalized == identifier.rawValue.lowercased() ||
                normalized == String(describing: identifier).lowercased()
            }) else {
                unknown.append(value)
                continue
            }
            identifiers.insert(match)
        }

        if !unknown.isEmpty {
            throw ValidationError("Unknown tools: \(unknown.joined(separator: ", "))")
        }

        return identifiers
    }

    static func parseAction(
        isImage: Bool,
        tools: Set<ToolIdentifier>
    ) -> Action {
        if isImage {
            return .imageGeneration(tools)
        }
        return .textGeneration(tools)
    }

    static func parseScheduleKind(_ value: String) throws -> AutomationScheduleKind {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
        switch normalized {
        case "cron":
            return .cron
        case "one_shot", "oneshot":
            return .oneShot
        default:
            throw ValidationError("Invalid schedule kind: \(value). Use cron or one_shot.")
        }
    }

    static func parseActionType(_ value: String) throws -> AutomationActionType {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "text":
            return .text
        case "image":
            return .image
        default:
            throw ValidationError("Invalid action type: \(value). Use text or image.")
        }
    }

    static func parseBackend(_ value: String) throws -> SendableModel.Backend {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "mlx":
            return .mlx
        case "gguf":
            return .gguf
        case "coreml":
            return .coreml
        case "remote":
            return .remote
        default:
            throw ValidationError("Invalid backend: \(value). Use mlx, gguf, coreml, or remote.")
        }
    }

    static func parseModelType(_ value: String) throws -> SendableModel.ModelType {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "diffusion":
            return .diffusion
        case "diffusionxl", "diffusion_xl":
            return .diffusionXL
        case "language":
            return .language
        case "deeplanguage", "deep_language":
            return .deepLanguage
        case "flexiblethinker", "flexible_thinker":
            return .flexibleThinker
        case "visuallanguage", "visual_language":
            return .visualLanguage
        default:
            throw ValidationError("Invalid model type: \(value).")
        }
    }

    static func parseArchitecture(_ value: String) -> Architecture {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return Architecture.allCases.first(where: { arch in
            normalized == arch.rawValue.lowercased() ||
                normalized == String(describing: arch).lowercased()
        }) ?? .unknown
    }
}
