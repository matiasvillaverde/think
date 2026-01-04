import Abstractions
import ArgumentParser
import Database
import Foundation

struct ModelsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "models",
        abstract: "Manage models (list, download, add, remove).",
        subcommands: [
            List.self,
            Info.self,
            Download.self,
            AddRemote.self,
            AddLocal.self,
            Remove.self
        ]
    )

    @OptionGroup
    var global: GlobalOptions
}

extension ModelsCommand {
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List known models."
        )

        @OptionGroup
        var global: GlobalOptions

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: global)
            let models = try await runtime.database.read(ModelCommands.FetchAll())
            let summaries = models.map(ModelSummary.init(model:))
            let fallback = summaries.isEmpty
                ? "No models."
                : summaries.map { "\($0.id.uuidString)  \($0.location)" }.joined(separator: "\n")
            runtime.output.emit(summaries, fallback: fallback)
        }
    }

    struct Info: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Get a model by id."
        )

        @OptionGroup
        var global: GlobalOptions

        @Argument(help: "Model UUID.")
        var id: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: global)
            let modelId = try CLIParsing.parseUUID(id, field: "model")
            let model = try await runtime.database.read(
                ModelCommands.GetSendableModel(id: modelId)
            )
            let summary = ModelSummary(model: model)
            runtime.output.emit(summary, fallback: "\(summary.id.uuidString)  \(summary.location)")
        }
    }

    struct Download: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Download a model from HuggingFace."
        )

        @OptionGroup
        var global: GlobalOptions

        @Argument(help: "Model repository id (e.g., mlx-community/Llama-3.2-1B).")
        var modelId: String

        @Option(name: .long, help: "Preferred backend (mlx, gguf, coreml).")
        var backend: String?

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: global)
            let explorer = runtime.downloader.explorer()
            let discovered = try await explorer.discoverModel(modelId)

            let preferredBackend: SendableModel.Backend?
            if let backend {
                preferredBackend = try CLIParsing.parseBackend(backend)
            } else {
                preferredBackend = nil
            }

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
        }
    }

    struct AddRemote: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Add a remote model reference."
        )

        @OptionGroup
        var global: GlobalOptions

        @Option(name: .long, help: "Model name.")
        var name: String

        @Option(name: .long, help: "Display name (defaults to name).")
        var displayName: String?

        @Option(name: .long, help: "Display description.")
        var description: String?

        @Option(name: .long, help: "Remote model location.")
        var location: String

        @Option(
            name: .long,
            help: .init(
                "Model type (language, diffusion, diffusionXL, deepLanguage, flexibleThinker, " +
                    "visualLanguage)."
            )
        )
        var type: String = "language"

        @Option(name: .long, help: "Architecture (optional).")
        var architecture: String = "unknown"

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: global)
            let modelType = try CLIParsing.parseModelType(type)
            let architectureValue = CLIParsing.parseArchitecture(architecture)
            let display = displayName ?? name
            let displayDescription = description ?? "Remote model"
            let modelId = try await runtime.database.write(
                ModelCommands.CreateRemoteModel(
                    name: name,
                    displayName: display,
                    displayDescription: displayDescription,
                    location: location,
                    type: modelType,
                    architecture: architectureValue
                )
            )
            runtime.output.emit("Added remote model \(modelId.uuidString)")
        }
    }

    struct AddLocal: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Add a local model reference."
        )

        @OptionGroup
        var global: GlobalOptions

        @Option(name: .long, help: "Model name.")
        var name: String

        @Option(name: .long, help: "Local model path.")
        var path: String

        @Option(name: .long, help: "Backend (mlx, gguf, coreml, remote).")
        var backend: String = "mlx"

        @Option(name: .long, help: "Model type.")
        var type: String = "language"

        @Option(name: .long, help: "Model parameters.")
        var parameters: UInt64 = 0

        @Option(name: .long, help: "RAM needed in bytes.")
        var ramNeeded: UInt64 = 0

        @Option(name: .long, help: "Model size in bytes.")
        var size: UInt64 = 0

        @Option(name: .long, help: "Architecture.")
        var architecture: String = "unknown"

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: global)
            let backendValue = try CLIParsing.parseBackend(backend)
            let modelType = try CLIParsing.parseModelType(type)
            let architectureValue = CLIParsing.parseArchitecture(architecture)
            let modelId = try await runtime.database.write(
                ModelCommands.CreateLocalModel(
                    name: name,
                    backend: backendValue,
                    type: modelType,
                    parameters: parameters,
                    ramNeeded: ramNeeded,
                    size: size,
                    architecture: architectureValue,
                    locationLocal: path,
                    locationBookmark: nil
                )
            )
            runtime.output.emit("Added local model \(modelId.uuidString)")
        }
    }

    struct Remove: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove a model from the database (and delete files if applicable)."
        )

        @OptionGroup
        var global: GlobalOptions

        @Argument(help: "Model UUID.")
        var id: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: global)
            let modelId = try CLIParsing.parseUUID(id, field: "model")
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
                ModelCommands.DeleteModelLocation(model: modelId)
            )
            runtime.output.emit("Removed model \(modelId.uuidString)")
        }
    }
}
