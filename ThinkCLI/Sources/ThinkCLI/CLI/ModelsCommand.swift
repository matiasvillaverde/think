import Abstractions
import ArgumentParser
import Foundation

struct ModelsCommand: AsyncParsableCommand, GlobalOptionsAccessing {
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

    @ParentCommand
    var parent: ThinkCLI

    var parentGlobal: GlobalOptions? { parent.global }
}

extension ModelsCommand {
    struct List: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "List known models."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ModelsCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            try await CLIModelsService.list(runtime: runtime)
        }
    }

    struct Info: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Get a model by id."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ModelsCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Argument(help: "Model UUID.")
        var id: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let modelId = try CLIParsing.parseUUID(id, field: "model")
            try await CLIModelsService.info(runtime: runtime, modelId: modelId)
        }
    }

    struct Download: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Download a model from HuggingFace."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ModelsCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Argument(help: "Model repository id (e.g., mlx-community/Llama-3.2-1B).")
        var modelId: String

        @Option(name: .long, help: "Preferred backend (mlx, gguf, coreml).")
        var backend: String?

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let preferredBackend = try backend.map(CLIParsing.parseBackend(_:))
            try await CLIModelsService.download(
                runtime: runtime,
                repositoryId: modelId,
                preferredBackend: preferredBackend
            )
        }
    }

    struct AddRemote: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Add a remote model reference."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ModelsCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

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
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let modelType = try CLIParsing.parseModelType(type)
            let architectureValue = CLIParsing.parseArchitecture(architecture)
            try await CLIModelsService.addRemote(
                runtime: runtime,
                name: name,
                displayName: displayName,
                description: description,
                location: location,
                type: modelType,
                architecture: architectureValue
            )
        }
    }

    struct AddLocal: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Add a local model reference."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ModelsCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

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
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let backendValue = try CLIParsing.parseBackend(backend)
            let modelType = try CLIParsing.parseModelType(type)
            let architectureValue = CLIParsing.parseArchitecture(architecture)
            try await CLIModelsService.addLocal(
                runtime: runtime,
                name: name,
                path: path,
                backend: backendValue,
                type: modelType,
                parameters: parameters,
                ramNeeded: ramNeeded,
                size: size,
                architecture: architectureValue
            )
        }
    }

    struct Remove: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Remove a model from the database (and delete files if applicable)."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ModelsCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Argument(help: "Model UUID.")
        var id: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let modelId = try CLIParsing.parseUUID(id, field: "model")
            try await CLIModelsService.remove(runtime: runtime, modelId: modelId)
        }
    }
}
