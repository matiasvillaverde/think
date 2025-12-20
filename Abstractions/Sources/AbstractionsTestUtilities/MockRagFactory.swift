import Foundation
import Abstractions

/// Mock implementation of RagFactory for testing
public class MockRagFactory: RagFactory, @unchecked Sendable {
    private let mockRag: Ragging
    private let error: Error?

    public init(mockRag: Ragging = MockRagging(), error: Error? = nil) {
        self.mockRag = mockRag
        self.error = error
    }

    public func createRag(
        isStoredInMemoryOnly: Bool,
        loadingStrategy: RagLoadingStrategy
    ) throws -> Ragging {
        if let error {
            throw error
        }
        return mockRag
    }

    public func createRag(isStoredInMemoryOnly: Bool) throws -> Ragging {
        try createRag(
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            loadingStrategy: .lazy
        )
    }
}
