import Abstractions
import Foundation

// MARK: - Local Model Resolution
extension ModelStateCoordinator {
    internal func resolveLocalModelLocation(sendableModel: SendableModel) throws -> URL {
        let localPath: String = sendableModel.locationLocal ?? sendableModel.location
        guard !localPath.isEmpty else {
            throw ModelStateCoordinatorError.emptyModelLocation
        }

        let resolvedURL: URL = try resolveLocalURL(
            localPath: localPath,
            bookmark: sendableModel.locationBookmark
        )

        var isDirectory: ObjCBool = false
        let exists: Bool = FileManager.default.fileExists(atPath: resolvedURL.path, isDirectory: &isDirectory)
        if !exists {
            throw ModelStateCoordinatorError.modelFileMissing(resolvedURL.path)
        }

        return resolvedURL
    }

    internal func stopAccessingSecurityScopedResourceIfNeeded() {
        guard let url = currentSecurityScopedURL else {
            return
        }
        url.stopAccessingSecurityScopedResource()
        currentSecurityScopedURL = nil
    }

    private func resolveLocalURL(localPath: String, bookmark: Data?) throws -> URL {
        if let bookmark {
            return try resolveBookmarkedURL(localPath: localPath, bookmark: bookmark)
        }
        return URL(fileURLWithPath: localPath)
    }

    private func resolveBookmarkedURL(localPath: String, bookmark: Data) throws -> URL {
        var isStale: Bool = false
        do {
            let resolvedURL: URL = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withoutUI, .withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                Self.logger.warning("Local model bookmark is stale for path: \(localPath)")
            }
            let started: Bool = resolvedURL.startAccessingSecurityScopedResource()
            if !started {
                throw ModelStateCoordinatorError.modelLocationNotResolved(localPath)
            }
            currentSecurityScopedURL = resolvedURL
            return resolvedURL
        } catch {
            throw ModelStateCoordinatorError.modelLocationNotResolved(localPath)
        }
    }
}
