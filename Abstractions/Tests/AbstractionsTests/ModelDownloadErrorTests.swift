import Foundation
import Testing
@testable import Abstractions

@Suite("ModelDownloadError Tests")
struct ModelDownloadErrorTests {
    @Test("Network error has correct properties")
    func testNetworkError() {
        // Given
        let underlyingError = URLError(.notConnectedToInternet)

        // When
        let error = ModelDownloadError.networkError(underlyingError)

        // Then
        #expect(error.isRetryable == true)
        #expect(error.errorDescription == "Network connection error")
        #expect(error.recoverySuggestion == "Please check your internet connection and try again")
    }

    @Test("Insufficient storage error has correct properties")
    func testInsufficientStorage() {
        // Given
        let required: UInt64 = 5_000_000_000 // 5GB
        let available: UInt64 = 1_000_000_000 // 1GB

        // When
        let error = ModelDownloadError.insufficientStorage(required: required, available: available)

        // Then
        #expect(error.isRetryable == false)
        #expect(error.errorDescription == "Insufficient storage space")
        #expect(error.recoverySuggestion?.contains("5 GB") == true)
        #expect(error.recoverySuggestion?.contains("1 GB") == true)
    }

    @Test("Insufficient memory error has correct properties")
    func testInsufficientMemory() {
        // Given
        let required: UInt64 = 8_000_000_000 // 8GB
        let available: UInt64 = 4_000_000_000 // 4GB

        // When
        let error = ModelDownloadError.insufficientMemory(required: required, available: available)

        // Then
        #expect(error.isRetryable == false)
        #expect(error.errorDescription == "Insufficient RAM: 8.0GB required, 4.0GB available")
        #expect(error.recoverySuggestion == "Close other applications or try a smaller model variant")
    }

    @Test("Model not found error has correct properties")
    func testModelNotFound() {
        // Given
        let modelId = UUID()

        // When
        let error = ModelDownloadError.modelNotFound(modelId)

        // Then
        #expect(error.isRetryable == false)
        #expect(error.errorDescription == "Model not found")
        #expect(error.recoverySuggestion == "The requested model could not be found")
    }

    @Test("Download cancelled error has correct properties")
    func testDownloadCancelled() {
        // When
        let error = ModelDownloadError.downloadCancelled

        // Then
        #expect(error.isRetryable == true)
        #expect(error.errorDescription == "Download cancelled")
        #expect(error.recoverySuggestion == "The download was cancelled by user request")
    }

    @Test("Server error has correct properties")
    func testServerError() {
        // Given
        let statusCode = 503

        // When
        let error = ModelDownloadError.serverError(statusCode: statusCode)

        // Then
        #expect(error.isRetryable == true)
        #expect(error.errorDescription == "Server error (503)")
        #expect(error.recoverySuggestion == "The server is temporarily unavailable. Please try again later")
    }

    @Test("Repository not found error has correct properties")
    func testRepositoryNotFound() {
        // Given
        let repository = "user/repo"

        // When
        let error = ModelDownloadError.repositoryNotFound(repository)

        // Then
        #expect(error.isRetryable == false)
        #expect(error.errorDescription == "Repository '\(repository)' not found on HuggingFace Hub")
        #expect(error.recoverySuggestion == "Check the repository name and ensure it exists on HuggingFace Hub")
    }

    @Test("Model already downloaded error has correct properties")
    func testModelAlreadyDownloaded() {
        // Given
        let modelId = UUID()

        // When
        let error = ModelDownloadError.modelAlreadyDownloaded(modelId)

        // Then
        #expect(error.isRetryable == false)
        #expect(error.errorDescription == "Model \(modelId.uuidString) is already downloaded")
        #expect(error.recoverySuggestion == "The model is already available for use")
    }

    @Test("Incompatible format error has correct properties")
    func testIncompatibleFormat() {
        // Given
        let modelType = SendableModel.ModelType.language
        let backend = SendableModel.Backend.mlx

        // When
        let error = ModelDownloadError.incompatibleFormat(modelType, backend)

        // Then
        #expect(error.isRetryable == false)
        #expect(error.errorDescription == "Model type 'language' is not compatible with backend 'mlx'")
        #expect(error.recoverySuggestion == "Try using MLX or GGUF format for language models")
    }

    @Test("Equatable conformance")
    func testEquatable() {
        // Test same errors are equal
        let error1 = ModelDownloadError.downloadCancelled
        let error2 = ModelDownloadError.downloadCancelled
        #expect(error1 == error2)

        // Test different errors are not equal
        let error3 = ModelDownloadError.modelNotFound(UUID())
        let error4 = ModelDownloadError.modelNotFound(UUID())
        #expect(error3 != error4) // Different UUIDs

        // Test same error with same data
        let id = UUID()
        let error5 = ModelDownloadError.modelNotFound(id)
        let error6 = ModelDownloadError.modelNotFound(id)
        #expect(error5 == error6)

        // Test repository not found
        let repoError1 = ModelDownloadError.repositoryNotFound("repo1")
        let repoError2 = ModelDownloadError.repositoryNotFound("repo1")
        let repoError3 = ModelDownloadError.repositoryNotFound("repo2")
        #expect(repoError1 == repoError2)
        #expect(repoError1 != repoError3)
    }

    @Test("LocalizedError conformance")
    func testLocalizedErrorConformance() {
        // Given
        let error = ModelDownloadError.networkError(URLError(.timedOut))

        // Then
        #expect(error.localizedDescription.contains("Network connection error") == true)
    }
}
