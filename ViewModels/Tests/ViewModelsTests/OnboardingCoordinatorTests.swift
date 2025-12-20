import Abstractions
import AbstractionsTestUtilities
@testable import Database
import Foundation
import Testing
@testable import ViewModels

@Suite("OnboardingCoordinator Tests")
internal struct OnboardingCoordinatorTests {
    // MARK: - Test Helpers

    private static func createTestDatabase() throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory()
        )
        return try Database.new(configuration: config)
    }

    private static func createV2ModelDTO(
        name: String,
        type: SendableModel.ModelType = .language,
        version: Int = 2
    ) -> ModelDTO {
        ModelDTO(
            type: type,
            backend: .mlx,
            name: name,
            displayName: name.capitalized,
            displayDescription: "\(name) model",
            skills: type == .language ? ["text generation"] : ["image generation"],
            parameters: type == .language ? 7_000_000_000 : 1_000_000_000,
            ramNeeded: type == .language ? 1_000_000_000 : 4_000_000_000,
            size: type == .language ? 4_000_000_000 : 2_000_000_000,
            locationHuggingface: "test-org/\(name)",
            version: version,
            architecture: .unknown
        )
    }
    @Test("Starts background downloads when created")
    @MainActor
    func startsBackgroundDownloadsWhenCreated() async throws {
        // Given
        let mockDownloader: MockTrackingModelDownloaderViewModel = MockTrackingModelDownloaderViewModel()
        let database: Database = try await Self.createTestDatabase()

        // When
        _ = OnboardingCoordinator(
            modelDownloaderViewModel: mockDownloader,
            database: database
        )

        // Wait for progress update
        try await Task.sleep(nanoseconds: 600_000_000) // 600ms

        // Then: Background downloads should have been resumed
        let downloadsCalled: Bool = await mockDownloader.resumeBackgroundDownloadsCalled
        #expect(downloadsCalled == true)
    }

    @Test("Reports progress after starting downloads")
    @MainActor
    func reportsProgressAfterStartingDownloads() async throws {
        // Given
        let mockDownloader: MockTrackingModelDownloaderViewModel = MockTrackingModelDownloaderViewModel()
        let database: Database = try await Self.createTestDatabase()

        // When
        let coordinator: OnboardingCoordinator = OnboardingCoordinator(
            modelDownloaderViewModel: mockDownloader,
            database: database
        )

        // Wait for initialization
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then: Should report progress as started
        let progress: Double = await coordinator.overallProgress
        #expect(progress == 0.5)

        let isComplete: Bool = await coordinator.isDownloadComplete
        #expect(isComplete == false)
    }

    @Test("Simplified download tracking")
    @MainActor
    func simplifiedDownloadTracking() async throws {
        // Given
        let mockDownloader: MockTrackingModelDownloaderViewModel = MockTrackingModelDownloaderViewModel()
        let database: Database = try await Self.createTestDatabase()

        // When
        let coordinator: OnboardingCoordinator = OnboardingCoordinator(
            modelDownloaderViewModel: mockDownloader,
            database: database
        )

        // Wait for initialization
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then: Initial state should show downloads in progress
        let initialProgress: Double = await coordinator.overallProgress
        #expect(initialProgress == 0.5)

        let initialComplete: Bool = await coordinator.isDownloadComplete
        #expect(initialComplete == false)

        // Note: In a real implementation, this would track actual download progress
        // For now, it's simplified to support the onboarding flow
    }
}

// MARK: - Mock Tracking Model Downloader

private actor MockTrackingModelDownloaderViewModel: ModelDownloaderViewModeling {
    var resumeBackgroundDownloadsCalled: Bool = false
    var requestNotificationPermissionCalled: Bool = false
    var pauseActiveDownloadsCalled: Bool = false

    func resumeBackgroundDownloads() {
        resumeBackgroundDownloadsCalled = true
    }

    func requestNotificationPermission() -> Bool {
        requestNotificationPermissionCalled = true
        return true
    }

    func pauseActiveDownloads() {
        pauseActiveDownloadsCalled = true
    }

    func downloadModel(_ discoveredModel: DiscoveredModel) {
        // No-op
    }

    func retryDownload(for modelId: UUID) {
        // No-op
    }

    func pauseDownload(for modelId: UUID) {
        // No-op
    }

    func resumeDownload(for modelId: UUID) {
        // No-op
    }

    func cancelDownload(for modelId: UUID) {
        // No-op
    }

    func deleteModel(_ modelId: UUID) {
        // No-op
    }

    func save(_ discovery: DiscoveredModel) -> UUID? {
        nil
    }

    func download(modelId: UUID) {
        // No-op
    }

    func cancelDownload(modelId: UUID) {
        // No-op
    }

    func delete(modelId: UUID) {
        // No-op
    }

    func pauseDownload(modelId: UUID) {
        // No-op
    }

    func resumeDownload(modelId: UUID) {
        // No-op
    }

    func handleBackgroundDownloadCompletion(
        identifier: String,
        completionHandler: @Sendable () -> Void
    ) {
        completionHandler()
    }

    func createModelEntry(for discovery: DiscoveredModel) -> UUID? {
        nil
    }
}
