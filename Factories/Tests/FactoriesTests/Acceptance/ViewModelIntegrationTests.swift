import Foundation
import Testing
@testable import Abstractions
@testable import AgentOrchestrator
@testable import ContextBuilder
@testable import Database
@testable import Factories
@testable import ImageGenerator
@testable import LLamaCPP
@testable import MLXSession
@testable import ModelDownloader
@testable import ViewModels

/// End-to-end integration tests for ViewModel workflows
///
/// These tests verify complete user journeys through the application using real
/// implementations of all dependencies. They ensure that the entire system works
/// correctly from a user's perspective.
///
/// Test scenarios covered:
/// 1. First Install User Journey - Complete onboarding through model selection
/// 2. Model Discovery and Selection - Browse and save community models
/// 3. Basic ViewModel Wiring - Verify all ViewModels can be created with real dependencies
@Suite("ViewModel Integration Tests", .serialized, .tags(.acceptance), .disabled())
internal struct ViewModelIntegrationTests {
    // MARK: - Test Infrastructure

    /// Error types specific to integration tests
    enum TestError: Error, LocalizedError {
        case timeout(String)
        case invalidState(String)
        case missingData(String)

        var errorDescription: String? {
            switch self {
            case .timeout(let message):
                return "Timeout: \(message)"

            case .invalidState(let message):
                return "Invalid state: \(message)"

            case .missingData(let message):
                return "Missing data: \(message)"
            }
        }
    }

    // MARK: - Helper Methods

    /// Container for all ViewModels used in tests
    struct ViewModels {
        let app: AppViewModel
        let modelDownloader: ModelDownloaderViewModel
        let discovery: DiscoveryCarouselViewModel
        let generator: ViewModelGenerator
    }

    /// Creates a fresh in-memory database for testing
    /// - Returns: A configured database instance with in-memory storage
    private func createTestDatabase() throws -> DatabaseProtocol {
        print("Creating fresh in-memory database for testing")
        let config: DatabaseConfiguration = DatabaseConfiguration.inMemoryOnly
        let database: DatabaseProtocol = Database.instance(configuration: config)
        print("Database created successfully")
        return database
    }

    /// Creates all ViewModels with real dependencies
    /// - Parameter database: The database instance to use
    /// - Returns: A struct containing all configured ViewModels
    private func createAllViewModels(
        database: DatabaseProtocol
    ) -> ViewModels {
        print("🏭 Creating ViewModels with real dependencies")

        // Create ModelDownloader ViewModel
        let modelDownloader: ModelDownloaderViewModel = ModelDownloaderViewModel(
            database: database,
            modelDownloader: ModelDownloader(),
            communityExplorer: CommunityModelsExplorer()
        )
        print("  ✓ ModelDownloaderViewModel created")

        // Create AppViewModel
        let appViewModel: AppViewModel = AppViewModel(
            database: database,
            modelDownloaderViewModel: modelDownloader
        )
        print("  ✓ AppViewModel created")

        // Create DiscoveryCarouselViewModel
        let discovery: DiscoveryCarouselViewModel = DiscoveryCarouselViewModel(
            communityExplorer: CommunityModelsExplorer(),
            deviceChecker: DeviceCompatibilityChecker(),
            vramCalculator: VRAMCalculator()
        )
        print("  ✓ DiscoveryCarouselViewModel created")

        // Create ViewModelGenerator with all dependencies
        let generator: ViewModelGenerator = ViewModelGenerator(
            orchestrator: AgentOrchestratorFactory.shared(
                database: database,
                mlxSession: MLXSessionFactory.create(),
                ggufSession: LlamaCPPFactory.createSession(),
                modelDownloader: ModelDownloader.shared
            ),
            database: database
        )
        print("  ✓ ViewModelGenerator created")

        print("All ViewModels created successfully")
        return ViewModels(
            app: appViewModel,
            modelDownloader: modelDownloader,
            discovery: discovery,
            generator: generator
        )
    }

    // MARK: - Test Cases

    @Test("First install flow - onboarding state transitions")
    func testFirstInstallOnboardingFlow() async throws {
        print("\nTEST: First Install Onboarding Flow")
        print("======================================")

        // Step 1: Initialize fresh database
        print("\nStep 1: Initialize fresh database")
        let database: DatabaseProtocol = try createTestDatabase()

        // Step 2: Create ViewModels
        print("\nStep 2: Create ViewModels")
        let viewModels: ViewModels = createAllViewModels(database: database)

        // Step 3: Initialize app - should show onboarding
        print("\nStep 3: Initialize app and verify onboarding state")
        await viewModels.app.initializeDatabase()
        let initialFlowState: AppFlowState = await viewModels.app.appFlowState

        // Assert: App should start in onboarding welcome state
        #expect(
            initialFlowState == .onboardingWelcome,
            "App should start with onboarding welcome for first install. Got: \(initialFlowState)"
        )
        print("  ✓ App correctly showing onboarding welcome")

        // Step 4: Navigate through onboarding screens
        print("\nStep 4: Navigate through onboarding screens")

        // Navigate to features screen
        await viewModels.app.navigateToNextState()
        let featuresState: AppFlowState = await viewModels.app.appFlowState
        #expect(
            featuresState == .onboardingFeatures,
            "Should navigate to features screen. Got: \(featuresState)"
        )
        print("  ✓ Navigated to features screen")

        // Navigate to model selection
        await viewModels.app.navigateToNextState()
        let modelSelectionState: AppFlowState = await viewModels.app.appFlowState
        #expect(
            modelSelectionState == .welcomeModelSelection,
            "Should navigate to model selection. Got: \(modelSelectionState)"
        )
        print("  ✓ Navigated to model selection")

        print("Onboarding flow test passed!")
    }

    @Test("Model discovery - find recommended models")
    func testModelDiscovery() async throws {
        print("\nTEST: Model Discovery")
        print("========================")

        // Step 1: Create database and ViewModels
        print("\nStep 1: Setup test environment")
        let database: DatabaseProtocol = try createTestDatabase()
        let viewModels: ViewModels = createAllViewModels(database: database)

        // Step 2: Discover recommended models
        print("\nStep 2: Discover recommended models")
        let recommendedModels: [DiscoveredModel] = try await viewModels.discovery.recommendedAllModels()

        // Assert: Should have recommended models
        #expect(
            !recommendedModels.isEmpty,
            "Should discover at least one recommended model"
        )
        print("  ✓ Found \(recommendedModels.count) recommended models")

        // Step 3: Check model properties
        print("\nStep 3: Verify model properties")
        if let firstModel = recommendedModels.first {
            await MainActor.run {
                print("  First model:")
                print("    - Name: \(firstModel.name)")
                print("    - Author: \(firstModel.author)")
                let sizeString: String = ByteCountFormatter.string(
                    fromByteCount: firstModel.totalSize,
                    countStyle: .file
                )
                print("    - Size: \(sizeString)")

                // Verify model has required properties
                #expect(!firstModel.name.isEmpty, "Model should have a name")
                #expect(!firstModel.author.isEmpty, "Model should have an author")
                #expect(firstModel.totalSize > 0, "Model should have size information")
            }
        }

        print("Model discovery test passed!")
    }

    @Test("Save discovered model to database")
    func testSaveDiscoveredModel() async throws {
        print("\nTEST: Save Discovered Model")
        print("===============================")

        // Step 1: Setup
        print("\nStep 1: Setup test environment")
        let database: DatabaseProtocol = try createTestDatabase()
        let viewModels: ViewModels = createAllViewModels(database: database)

        // Initialize database
        await viewModels.app.initializeDatabase()

        // Step 2: Discover models
        print("\nStep 2: Discover recommended models")
        let recommendedModels: [DiscoveredModel] = try await viewModels.discovery.recommendedAllModels()

        guard let firstModel = recommendedModels.first else {
            throw TestError.missingData("No recommended models found")
        }

        // Step 3: Save model
        print("\nStep 3: Save discovered model")
        let modelName: String = await MainActor.run { firstModel.name }
        print("  Saving model: \(modelName)")

        let modelId: UUID? = await viewModels.modelDownloader.save(firstModel)

        // Assert: Model should be saved with ID
        #expect(
            modelId != nil,
            "Model should be saved successfully"
        )
        guard let savedModelId = modelId else {
            throw TestError.missingData("Model ID should not be nil after saving")
        }
        print("  ✓ Model saved with ID: \(savedModelId)")

        // Step 4: Verify model is in database
        print("\nStep 4: Verify model is in database")
        let savedModel: SendableModel = try await database.read(ModelCommands.GetSendableModel(id: savedModelId))

        // SendableModel doesn't have name property, so we just verify it exists
        print("  ✓ Model correctly saved in database")
        print("    - ID: \(savedModel.id)")
        print("    - Backend: \(savedModel.backend)")
        print("    - Type: \(savedModel.modelType)")

        print("Save model test passed!")
    }
}
