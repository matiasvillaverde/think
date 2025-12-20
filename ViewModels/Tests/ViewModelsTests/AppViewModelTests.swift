import Abstractions
import AbstractionsTestUtilities
@testable import Database
import Foundation
import Testing
@testable import ViewModels

@Suite("AppViewModel Tests")
internal enum AppViewModelTests {
    @Suite("App Flow State Logic")
    struct AppFlowStateTests {
        @Test("Should show onboarding welcome when no chats exist")
        @MainActor
        func shouldShowOnboardingWelcomeWhenNoChats() async throws {
            // Given: Database with no chats and no v2 models
            let config: DatabaseConfiguration = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory()
            )
            let database: Database = try Database.new(configuration: config)

            // Don't initialize database to ensure no models are created
            // This simulates a completely fresh install

            let mockDownloader: MockModelDownloaderViewModel = MockModelDownloaderViewModel()
            let appViewModel: AppViewModel = AppViewModel(
                database: database,
                modelDownloaderViewModel: mockDownloader
            )

            // Initialize the AppViewModel (which calls AppCommands.Initialize)
            await appViewModel.initializeDatabase()

            // When: Check the app flow state
            let appFlowState: AppFlowState = await appViewModel.appFlowState

            // Then: Should show onboarding welcome screen because no chats and no v2 models exist
            #expect(appFlowState == .onboardingWelcome)
        }

        @Test("Should show main app when chats exist")
        @MainActor
        func shouldShowMainAppWhenChatsExist() async throws {
            // Given: Database with existing chat
            let config: DatabaseConfiguration = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory()
            )
            let database: Database = try Database.new(configuration: config)

            // Create v2 models so initialize will create a chat
            try await AppViewModelTests.createV2Models(in: database)

            let mockDownloader: MockModelDownloaderViewModel = MockModelDownloaderViewModel()
            let appViewModel: AppViewModel = AppViewModel(
                database: database,
                modelDownloaderViewModel: mockDownloader
            )

            // Initialize the AppViewModel (which calls AppCommands.Initialize)
            await appViewModel.initializeDatabase()

            // When: Check the app flow state
            let appFlowState: AppFlowState = await appViewModel.appFlowState

            // Then: Should show main app, not onboarding
            #expect(appFlowState == .mainApp)
        }

        @Test("Should navigate through onboarding states")
        @MainActor
        func shouldNavigateThroughOnboardingStates() async throws {
            // Given: Fresh install
            let config: DatabaseConfiguration = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory()
            )
            let database: Database = try Database.new(configuration: config)

            let mockDownloader: MockModelDownloaderViewModel = MockModelDownloaderViewModel()
            let appViewModel: AppViewModel = AppViewModel(
                database: database,
                modelDownloaderViewModel: mockDownloader
            )

            await appViewModel.initializeDatabase()

            // Should start at onboarding welcome
            var state: AppFlowState = await appViewModel.appFlowState
            #expect(state == .onboardingWelcome)

            // Navigate to features
            await appViewModel.navigateToNextState()
            state = await appViewModel.appFlowState
            #expect(state == .onboardingFeatures)

            // Navigate to model selection
            await appViewModel.navigateToNextState()
            state = await appViewModel.appFlowState
            #expect(state == .welcomeModelSelection)

            // Navigate to main app
            await appViewModel.navigateToNextState()
            state = await appViewModel.appFlowState
            #expect(state == .mainApp)
        }

        @Test("Should complete onboarding directly")
        @MainActor
        func shouldCompleteOnboardingDirectly() async throws {
            // Given: Fresh install
            let config: DatabaseConfiguration = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory()
            )
            let database: Database = try Database.new(configuration: config)

            let mockDownloader: MockModelDownloaderViewModel = MockModelDownloaderViewModel()
            let appViewModel: AppViewModel = AppViewModel(
                database: database,
                modelDownloaderViewModel: mockDownloader
            )

            await appViewModel.initializeDatabase()

            // Should start at onboarding welcome
            var state: AppFlowState = await appViewModel.appFlowState
            #expect(state == .onboardingWelcome)

            // Complete onboarding
            await appViewModel.completeOnboarding()
            state = await appViewModel.appFlowState
            #expect(state == .mainApp)
        }
    }

    @Suite("Initial Chat Setup")
    struct InitialChatSetupTests {
        @Test("Sets up initial chat with selected model")
        @MainActor
        func setupInitialChatWithSelectedModel() async throws {
            // Given: Database with models but no chats
            let config: DatabaseConfiguration = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory()
            )
            let database: Database = try Database.new(configuration: config)

            // Initialize database 
            let result: AppCommands.Initialize.Result = try await database.execute(AppCommands.Initialize())
            // For this test we want no chats, so we expect welcome screen
            #expect(result.targetScreen == AppScreen.welcome)

            // Create a test language model manually
            let languageModelDTO: ModelDTO = ModelDTO(
                type: .language,
                backend: .mlx,
                name: "test-language-model",
                displayName: "Test Language Model",
                displayDescription: "A test language model",
                skills: ["text generation"],
                parameters: 7_000_000_000,
                ramNeeded: 1_000_000_000,
                size: 4_000_000_000,
                locationHuggingface: "test-org/language-model",
                version: 2,
                architecture: .unknown
            )

            try await database.write(ModelCommands.AddModels(models: [languageModelDTO]))
            let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())
            guard let languageModel = models.first(where: { $0.modelType == .language }) else {
                Issue.record("Failed to create test language model")
                return
            }

            let mockDownloader: MockModelDownloaderViewModel = MockModelDownloaderViewModel()
            let appViewModel: AppViewModel = AppViewModel(
                database: database,
                modelDownloaderViewModel: mockDownloader
            )

            // Initialize the AppViewModel first
            await appViewModel.initializeDatabase()

            // When: Setup initial chat with selected model
            try await appViewModel.setupInitialChat(with: languageModel.id)

            // Then: Chat should be created
            let hasChats: Bool = try await database.read(ChatCommands.HasChats())
            #expect(hasChats == true)

            // Re-initialize to update the target screen after chat creation
            await appViewModel.initializeDatabase()

            // Verify the target screen changed to chat
            let targetScreenAfterSetup: AppScreen = await appViewModel.targetScreen
            #expect(targetScreenAfterSetup == AppScreen.chat)
        }

        @Test("Throws error when model not found")
        @MainActor
        func setupInitialChatThrowsWhenModelNotFound() async throws {
            // Given: Database with no chats
            let config: DatabaseConfiguration = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory()
            )
            let database: Database = try Database.new(configuration: config)

            let result: AppCommands.Initialize.Result = try await database.execute(AppCommands.Initialize())
            #expect(result.targetScreen == AppScreen.welcome)

            let mockDownloader: MockModelDownloaderViewModel = MockModelDownloaderViewModel()
            let appViewModel: AppViewModel = AppViewModel(
                database: database,
                modelDownloaderViewModel: mockDownloader
            )

            let nonExistentModelId: UUID = UUID()

            // When/Then: Should throw model not found error
            await #expect(throws: DatabaseError.modelNotFound) {
                try await appViewModel.setupInitialChat(with: nonExistentModelId)
            }
        }
    }

    // MARK: - Helper Methods
    static func createV2Models(in database: DatabaseProtocol) async throws {
        // Create v2 language model  
        let languageModel: ModelDTO = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-v2-language-model",
            displayName: "Test V2 Language Model",
            displayDescription: "A test v2 language model",
            skills: ["text generation"],
            parameters: 7_000_000_000,
            ramNeeded: 1_000_000_000,
            size: 4_000_000_000,
            locationHuggingface: "test-org/v2-language-model",
            version: 2,
            architecture: .unknown
        )

        // Create v2 image model
        let imageModel: ModelDTO = ModelDTO(
            type: .diffusion,
            backend: .mlx,
            name: "test-v2-image-model",
            displayName: "Test V2 Image Model",
            displayDescription: "A test v2 image model",
            skills: ["image generation"],
            parameters: 1_000_000_000,
            ramNeeded: 4_000_000_000,
            size: 2_000_000_000,
            locationHuggingface: "test-org/v2-image-model",
            version: 2,
            architecture: .unknown
        )

        try await database.write(ModelCommands.AddModels(models: [languageModel, imageModel]))

        // Set models to downloaded state so they're considered "available"
        let addedModels: [SendableModel] = try await database.read(ModelCommands.FetchAll())
        for model in addedModels {
            try await database.write(ModelCommands.UpdateModelDownloadProgress(
                id: model.id,
                progress: 1.0  // 100% complete = downloaded
            ))
        }
    }
}

// MARK: - Mock Model Downloader
internal struct MockModelDownloaderViewModel: ModelDownloaderViewModeling {
    func resumeBackgroundDownloads() {
        // No-op for tests
    }

    func requestNotificationPermission() -> Bool {
        true // Always grant for tests
    }

    func pauseActiveDownloads() {
        // No-op for tests
    }

    func downloadModel(_ discoveredModel: DiscoveredModel) {
        // No-op for tests
    }

    func retryDownload(for modelId: UUID) {
        // No-op for tests
    }

    func pauseDownload(for modelId: UUID) {
        // No-op for tests
    }

    func resumeDownload(for modelId: UUID) {
        // No-op for tests
    }

    func cancelDownload(for modelId: UUID) {
        // No-op for tests
    }

    func deleteModel(_ modelId: UUID) {
        // No-op for tests
    }

    func save(_ discovery: DiscoveredModel) -> UUID? {
        // No-op for tests
        nil
    }

    func download(modelId: UUID) {
        // No-op for tests
    }

    func cancelDownload(modelId: UUID) {
        // No-op for tests
    }

    func delete(modelId: UUID) {
        // No-op for tests
    }

    func pauseDownload(modelId: UUID) {
        // No-op for tests
    }

    func resumeDownload(modelId: UUID) {
        // No-op for tests
    }

    func handleBackgroundDownloadCompletion(
        identifier: String,
        completionHandler: @Sendable () -> Void
    ) {
        // No-op for tests
        completionHandler()
    }

    func createModelEntry(for discovery: DiscoveredModel) -> UUID? {
        // No-op for tests
        nil
    }
}
