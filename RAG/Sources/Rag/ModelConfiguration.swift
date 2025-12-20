import Foundation

/// Configuration for RAG model loading parameters
internal struct ModelConfiguration: Sendable {
    let hubRepoId: String
    let localURL: URL?
    let useBackgroundSession: Bool

    init(
        hubRepoId: String,
        localURL: URL? = nil,
        useBackgroundSession: Bool = false
    ) {
        self.hubRepoId = hubRepoId
        self.localURL = localURL
        self.useBackgroundSession = useBackgroundSession
    }
}
