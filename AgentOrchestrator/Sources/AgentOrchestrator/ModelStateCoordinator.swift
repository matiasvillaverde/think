import Abstractions
import Database
import Foundation
import ModelDownloader
import OSLog

/// Coordinates model loading and state synchronization between LLMSession and Database
internal final actor ModelStateCoordinator {
    internal static let logger: Logger = Logger(
        subsystem: "AgentOrchestrator",
        category: "ModelStateCoordinator"
    )

    private let database: DatabaseProtocol
    private let mlxSession: LLMSession
    private let ggufSession: LLMSession
    private let imageGenerator: ImageGenerating
    internal let modelDownloader: ModelDownloaderProtocol
    private var currentModelId: UUID?
    private var currentSession: LLMSession?
    private var isCurrentModelImage: Bool = false

    /// Initialize coordinator with database, LLM sessions, and image generator
    internal init(
        database: DatabaseProtocol,
        mlxSession: LLMSession,
        ggufSession: LLMSession,
        imageGenerator: ImageGenerating,
        modelDownloader: ModelDownloaderProtocol
    ) {
        self.database = database
        self.mlxSession = mlxSession
        self.ggufSession = ggufSession
        self.imageGenerator = imageGenerator
        self.modelDownloader = modelDownloader
    }

    deinit {
        Task.detached { [currentModelId, currentSession, database, isCurrentModelImage, imageGenerator] in
            // Unload current model if one is loaded
            guard let modelId = currentModelId else {
                return
            }

            if isCurrentModelImage {
                // Cannot use self methods in deinit, create inline
                try? await imageGenerator.unload(model: modelId)
            } else if let session = currentSession {
                session.stop()
                await session.unload()
            }

            // Update database state to reflect unloaded
            _ = try? await database.write(
                ModelCommands.TransitionRuntimeState(
                    id: modelId,
                    transition: .unload
                )
            )
        }
    }

    /// Load model for a specific chat
    internal func load(chatId: UUID) async throws {
        Self.logger.info("Loading model for chat: \(chatId)")

        // Get the language model using command
        let sendableModel: SendableModel = try await database.read(
            ChatCommands.GetLanguageModel(chatId: chatId)
        )

        let modelId: UUID = sendableModel.id

        // Check if already loaded
        if let currentId = currentModelId, currentId == modelId {
            Self.logger.debug("Model \(modelId) already loaded, skipping")
            return
        }

        // Unload current model if different
        if currentModelId != nil {
            Self.logger.info("Unloading current model to load new model: \(modelId)")
            try await unloadCurrent()
        }

        try await loadModel(modelId, chatId: chatId, sendableModel: sendableModel)
    }

    /// Unload the currently loaded model
    internal func unload() async throws {
        guard let modelId = currentModelId else {
            Self.logger.debug("No model loaded, skipping unload")
            return
        }

        Self.logger.info("Unloading model: \(modelId)")
        try await unloadCurrent()
    }

    /// Stream text generation from the loaded model
    internal func stream(_ input: LLMInput) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        guard let session = currentSession, let modelId = currentModelId else {
            Self.logger.error("Cannot stream: no model loaded")
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: DatabaseError.modelNotFound)
            }
        }

        return createStreamForSession(session, modelId: modelId, input: input)
    }

    /// Generate images using a CoreML model
    internal func generate(
        model: SendableModel,
        config: ImageConfiguration
    ) -> AsyncThrowingStream<ImageGenerationProgress, Error> {
        Self.logger.info("Starting image generation with model: \(model.id)")

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await performImageGeneration(
                        model: model,
                        config: config,
                        continuation: continuation
                    )
                } catch {
                    Self.logger.error("Image generation failed: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Stop the current generation
    internal func stop() async throws {
        guard let modelId = currentModelId else {
            Self.logger.warning("No model loaded, nothing to stop")
            return
        }

        Self.logger.info("Stopping generation for model: \(modelId)")

        if isCurrentModelImage {
            // Stop image generation
            try await imageGenerator.stop(model: modelId)
        } else if let session = currentSession {
            // Stop text generation
            session.stop()
        }

        try await database.write(
            ModelCommands.TransitionRuntimeState(id: modelId, transition: .stopGeneration)
        )
    }

    // MARK: - Private Helpers

    private func loadModel(_ modelId: UUID, chatId _: UUID, sendableModel: SendableModel) async throws {
        Self.logger.info("Loading model \(modelId) with backend: \(sendableModel.backend.rawValue)")

        try await transitionToLoading(modelId)

        let session: LLMSession = sendableModel.backend == .gguf ? ggufSession : mlxSession

        let config: ProviderConfiguration = try await createConfiguration(sendableModel: sendableModel)

        for try await _ in await session.preload(configuration: config) {
            // Progress streaming handled here
        }

        try await transitionToLoaded(modelId)

        currentModelId = modelId
        currentSession = session
        Self.logger.info("Model \(modelId) loaded successfully")
    }

    private static let defaultContextSize: Int = 2_048

    private func createConfiguration(sendableModel: SendableModel) async throws -> ProviderConfiguration {
        let localPath: URL = try await resolveModelLocation(sendableModel: sendableModel)
        let contextSize: Int = sendableModel.metadata?.contextLength ?? Self.defaultContextSize

        return ProviderConfiguration(
            location: localPath,
            authentication: .noAuth,
            modelName: sendableModel.location,
            compute: ComputeConfiguration(
                contextSize: contextSize,
                batchSize: getBatchSizeForAppleSilicon(),
                threadCount: ProcessInfo.processInfo.processorCount
            )
        )
    }

    private func createStreamForSession(
        _ session: LLMSession,
        modelId: UUID,
        input: LLMInput
    ) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.transitionToGenerating(modelId)
                    for try await chunk in await session.stream(input) {
                        continuation.yield(chunk)
                    }
                    try await self.transitionFromGenerating(modelId)
                    continuation.finish()
                } catch {
                    try? await self.transitionFromGenerating(modelId)
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func transitionToLoading(_ modelId: UUID) async throws {
        try await database.write(
            ModelCommands.TransitionRuntimeState(id: modelId, transition: .load)
        )
    }

    private func transitionToLoaded(_ modelId: UUID) async throws {
        try await database.write(
            ModelCommands.TransitionRuntimeState(id: modelId, transition: .completeLoad)
        )
    }

    private func transitionToGenerating(_ modelId: UUID) async throws {
        try await database.write(
            ModelCommands.TransitionRuntimeState(id: modelId, transition: .startGeneration)
        )
    }

    private func transitionFromGenerating(_ modelId: UUID) async throws {
        try await database.write(
            ModelCommands.TransitionRuntimeState(id: modelId, transition: .stopGeneration)
        )
    }

    private func unloadCurrent() async throws {
        guard let modelId = currentModelId else {
            return
        }

        Self.logger.debug("Unloading current model: \(modelId)")

        if isCurrentModelImage {
            try await imageGenerator.unload(model: modelId)
        } else if let session = currentSession {
            await session.unload()
        }

        try await database.write(
            ModelCommands.TransitionRuntimeState(id: modelId, transition: .unload)
        )
        currentModelId = nil
        currentSession = nil
        isCurrentModelImage = false
    }

    private func performImageGeneration(
        model: SendableModel,
        config: ImageConfiguration,
        continuation: AsyncThrowingStream<ImageGenerationProgress, Error>.Continuation
    ) async throws {
        if currentModelId != nil {
            try await unloadCurrent()
        }
        try await loadImageModel(model)
        for try await progress in await imageGenerator.generate(model: model, config: config) {
            continuation.yield(progress)
        }
        try await unloadImageModel(model)
        continuation.finish()
    }

    private func loadImageModel(_ model: SendableModel) async throws {
        try await transitionToLoading(model.id)
        for try await _ in await imageGenerator.load(model: model) {
            // Progress updates handled by ImageGenerating
        }
        try await transitionToLoaded(model.id)
        currentModelId = model.id
        currentSession = nil
        isCurrentModelImage = true
    }

    private func unloadImageModel(_ model: SendableModel) async throws {
        try await imageGenerator.unload(model: model.id)
        try await database.write(
            ModelCommands.TransitionRuntimeState(id: model.id, transition: .unload)
        )
        currentModelId = nil
        currentSession = nil
        isCurrentModelImage = false
    }
}
