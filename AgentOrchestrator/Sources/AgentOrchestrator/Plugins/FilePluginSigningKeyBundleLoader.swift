import Abstractions
import Foundation

/// Loads a signing key bundle from disk.
public struct FilePluginSigningKeyBundleLoader: PluginSigningKeyBundleLoading {
    private let fileURL: URL
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func loadBundle() async throws -> PluginSigningKeyBundle {
        await Task.yield()
        let data: Data = try Data(contentsOf: fileURL)
        return try decoder.decode(PluginSigningKeyBundle.self, from: data)
    }
}
