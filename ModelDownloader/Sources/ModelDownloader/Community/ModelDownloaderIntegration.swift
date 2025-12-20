import Abstractions
import Foundation

// MARK: - ModelDownloader Integration

extension ModelDownloader {
    /// Explore and discover models from HuggingFace communities
    /// - Returns: CommunityModelsExplorer instance for model discovery
    public func explorer() -> CommunityModelsExplorer {
        CommunityModelsExplorer()
    }

    /// Download a discovered model
    /// - Parameters:
    ///   - model: The discovered model to download
    ///   - preferredBackend: Optional preferred backend (uses primary detected if nil)
    /// - Returns: AsyncThrowingStream of download events
    public func download(
        _ model: DiscoveredModel,
        preferredBackend: SendableModel.Backend? = nil
    ) -> AsyncThrowingStream<DownloadEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Convert to SendableModel
                    let explorer: CommunityModelsExplorer = CommunityModelsExplorer()
                    let sendableModel: SendableModel = try await explorer.prepareForDownload(
                        model,
                        preferredBackend: preferredBackend
                    )

                    // Start download using existing infrastructure
                    let downloadStream: AsyncThrowingStream<DownloadEvent, Error> = self.downloadModel(
                        sendableModel: sendableModel
                    )

                    // Forward events from the download stream
                    for try await event in downloadStream {
                        continuation.yield(event)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - CommunityModelsExplorer Convenience

extension CommunityModelsExplorer {
    /// Download a model directly using ModelDownloader
    /// - Parameters:
    ///   - model: The discovered model to download
    ///   - downloader: ModelDownloader instance
    ///   - preferredBackend: Optional preferred backend
    /// - Returns: AsyncThrowingStream of download events
    public func downloadModel(
        _ model: DiscoveredModel,
        using downloader: ModelDownloader,
        preferredBackend: SendableModel.Backend? = nil
    ) -> AsyncThrowingStream<DownloadEvent, Error> {
        downloader.download(model, preferredBackend: preferredBackend)
    }

    /// Search and download in one operation
    /// - Parameters:
    ///   - modelId: Model identifier to search for and download
    ///   - downloader: ModelDownloader instance
    ///   - preferredBackend: Optional preferred backend
    /// - Returns: AsyncThrowingStream of download events
    public func searchAndDownload(
        modelId: String,
        using downloader: ModelDownloader,
        preferredBackend: SendableModel.Backend? = nil
    ) -> AsyncThrowingStream<DownloadEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Discover the model
                    let model: DiscoveredModel = try await self.discoverModel(modelId)

                    // Validate it has supported backends
                    guard await !model.detectedBackends.isEmpty else {
                        throw HuggingFaceError.unsupportedFormat
                    }

                    // Download using the downloader
                    let downloadStream: AsyncThrowingStream<DownloadEvent, Error> = downloader.download(
                        model,
                        preferredBackend: preferredBackend
                    )

                    // Forward events
                    for try await event in downloadStream {
                        continuation.yield(event)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
