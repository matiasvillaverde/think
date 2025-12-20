public protocol RagFactory: Sendable {
    func createRag(
        isStoredInMemoryOnly: Bool,
        loadingStrategy: RagLoadingStrategy
    ) async throws -> Ragging

    func createRag(isStoredInMemoryOnly: Bool) async throws -> Ragging
}
