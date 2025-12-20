import Foundation

/// Protocol for streaming download operations
public protocol StreamingDownloaderProtocol: Actor {
    func download(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL

    func downloadResume(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL

    func cancel(url: URL) async

    func cancelAll() async

    func pause(url: URL) async

    func pauseAll() async

    func resume(url: URL) async

    func resumeAll() async
}

/// Extension to make StreamingDownloader conform to the protocol
extension StreamingDownloader: StreamingDownloaderProtocol {}
