import Abstractions
import Database
import Foundation

enum CLIModelsService {
    static func list(runtime: CLIRuntime) async throws {
        let models = try await runtime.database.read(ModelCommands.FetchAll())
        let summaries = models.map(ModelSummary.init(model:))
        let fallback = summaries.isEmpty
            ? "No models."
            : summaries.map { "\($0.id.uuidString)  \($0.location)" }.joined(separator: "\n")
        runtime.output.emit(summaries, fallback: fallback)
    }

    static func info(runtime: CLIRuntime, modelId: UUID) async throws {
        let model = try await runtime.database.read(
            ModelCommands.GetSendableModel(id: modelId)
        )
        let summary = ModelSummary(model: model)
        runtime.output.emit(summary, fallback: "\(summary.id.uuidString)  \(summary.location)")
    }

    static func download(
        runtime: CLIRuntime,
        repositoryId: String,
        preferredBackend: SendableModel.Backend?
    ) async throws {
        do {
            let explorer = runtime.downloader.explorer()
            let discovered = try await explorer.discoverModel(repositoryId)
            let sendable = try await explorer.prepareForDownload(
                discovered,
                preferredBackend: preferredBackend
            )

            let createCommand = await MainActor.run {
                ModelCommands.CreateFromDiscovery(
                    discoveredModel: discovered,
                    sendableModel: sendable
                )
            }
            _ = try await runtime.database.write(createCommand)

            runtime.output.emit("Downloading \(sendable.location)...")

            for try await event in runtime.downloader.download(sendableModel: sendable) {
                switch event {
                case .progress(let progress):
                    try await runtime.database.write(
                        ModelCommands.UpdateModelDownloadProgress(
                            id: sendable.id,
                            progress: progress.fractionCompleted
                        )
                    )
                    runtime.output.emit(progress.description)
                case .completed(let info):
                    _ = try await runtime.database.write(
                        ModelCommands.UpdateModelDownloadProgress(id: sendable.id, progress: 1.0)
                    )
                    runtime.output.emit(
                        "Download completed: \(info.name) (\(info.backend.rawValue))"
                    )
                }
            }
        } catch {
            throw mapDownloadError(error)
        }
    }

    static func addRemote(
        runtime: CLIRuntime,
        name: String,
        displayName: String?,
        description: String?,
        location: String,
        type: SendableModel.ModelType,
        architecture: Architecture
    ) async throws {
        let display = displayName ?? name
        let displayDescription = description ?? "Remote model"
        let modelId = try await runtime.database.write(
            ModelCommands.CreateRemoteModel(
                name: name,
                displayName: display,
                displayDescription: displayDescription,
                location: location,
                type: type,
                architecture: architecture
            )
        )
        runtime.output.emit("Added remote model \(modelId.uuidString)")
    }

    static func addLocal(
        runtime: CLIRuntime,
        name: String,
        path: String,
        backend: SendableModel.Backend,
        type: SendableModel.ModelType,
        parameters: UInt64,
        ramNeeded: UInt64,
        size: UInt64,
        architecture: Architecture
    ) async throws {
        let modelId = try await runtime.database.write(
            ModelCommands.CreateLocalModel(
                name: name,
                backend: backend,
                type: type,
                parameters: parameters,
                ramNeeded: ramNeeded,
                size: size,
                architecture: architecture,
                locationLocal: path,
                locationBookmark: nil
            )
        )
        runtime.output.emit("Added local model \(modelId.uuidString)")
    }

    static func remove(runtime: CLIRuntime, modelId: UUID) async throws {
        let sendable = try await runtime.database.read(
            ModelCommands.GetSendableModel(id: modelId)
        )

        if sendable.locationKind == .huggingFace {
            do {
                try await runtime.downloader.delete(modelLocation: sendable.location)
            } catch {
                runtime.output.emit(
                    "Warning: failed to delete files (\(error.localizedDescription))"
                )
            }
        }

        _ = try await runtime.database.write(
            ModelCommands.DeleteModel(model: modelId)
        )
        runtime.output.emit("Removed model \(modelId.uuidString)")
    }


    private static func mapDownloadError(_ error: Error) -> Error {
        let message = error.localizedDescription
        let isAuthError = message.contains("status code: 401")
            || message.lowercased().contains("authentication required")
        if isAuthError {
            return CLIError(
                message: "HuggingFace auth required. Set HF_TOKEN (or token file) and retry.",
                exitCode: .permission
            )
        }
        return error
    }
}
