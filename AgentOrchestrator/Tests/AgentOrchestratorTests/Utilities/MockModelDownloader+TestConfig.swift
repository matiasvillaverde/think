import AbstractionsTestUtilities
import Foundation

private let kTestModelSizeBytes: Int64 = 100_000_000 // 100MB default

extension MockModelDownloader {
    /// Configure the mock with common test model locations
    internal func configureForStandardTests() {
        configureTestModels()
    }

    /// Create a MockModelDownloader configured for standard tests
    internal static func createConfiguredMock() -> MockModelDownloader {
        let mock: MockModelDownloader = MockModelDownloader()
        mock.configureForStandardTests()
        return mock
    }

    private func configureTestModels() {
        let testModels: [String] = getTestModelList()
        for model in testModels {
            let location: URL = URL(
                fileURLWithPath: "/tmp/models/\(model.replacingOccurrences(of: "/", with: "_"))"
            )
            configureModel(
                for: model,
                location: location,
                exists: true,
                size: kTestModelSizeBytes
            )
        }
    }

    private func getTestModelList() -> [String] {
        [
            "test/model", "test/language", "test/model-1", "test/model-2", "test/model-3",
            "test/mlx-llm", "test/gguf-llm", "test-language-model", "test-gguf-model",
            "test/mlx-model", "test/gguf-model", "test/specific-model",
            "test/model-a", "test/model-b",
            "test/complex",
            "mlx-community/Qwen3-1.7B-4bit", "mlx-community/test-repo-id",
            "mlx-community/NotDownloadedModel", "test-org/test-gguf-model",
            "TheBloke/Llama-2-7B-GGUF",
            "https://example.com/model", "path/to/model", "file:///Users/test/model.gguf"
        ]
    }
}
