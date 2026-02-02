import Foundation
import OSLog

internal enum CLIMetalLibraryBootstrapper {
    private static let logger: Logger = Logger(subsystem: "ThinkCLI", category: "MetalLibrary")
    private static let bundleName: String = "mlx-swift_Cmlx.bundle"
    private static let metallibRelativePath: String = "Contents/Resources/default.metallib"

    static func ensureMetallibAvailable(
        executableURL: URL? = Bundle.main.executableURL,
        fileManager: FileManager = .default,
        searchRoots: [URL]? = nil
    ) -> Bool {
        guard let executableURL else {
            return false
        }

        let executableDir: URL = executableURL.deletingLastPathComponent()
        let resourcesDir: URL = executableDir.appendingPathComponent("Resources", isDirectory: true)
        let targetMetallib: URL = resourcesDir.appendingPathComponent("default.metallib")

        if fileManager.fileExists(atPath: targetMetallib.path) {
            return true
        }

        let roots: [URL] = searchRoots ?? defaultSearchRoots(
            executableDir: executableDir,
            fileManager: fileManager
        )
        guard let sourceMetallib: URL = locateMetallib(
            in: roots,
            fileManager: fileManager
        ) else {
            return false
        }

        do {
            try fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: targetMetallib.path) {
                return true
            }
            try fileManager.copyItem(at: sourceMetallib, to: targetMetallib)
            let infoMessage: String = "Copied MLX metallib to \(targetMetallib.path)"
            logger.info("\(infoMessage, privacy: .public)")
            return true
        } catch {
            let message: String = "Failed to copy MLX metallib: \(error.localizedDescription)"
            logger.error("\(message, privacy: .public)")
            return false
        }
    }

    private static func defaultSearchRoots(
        executableDir: URL,
        fileManager: FileManager
    ) -> [URL] {
        var roots: [URL] = [executableDir]
        roots.append(executableDir.deletingLastPathComponent())
        roots.append(URL(fileURLWithPath: fileManager.currentDirectoryPath))

        var seen: Set<String> = []
        let uniqueRoots: [URL] = roots.filter { seen.insert($0.path).inserted }
        return uniqueRoots
    }

    private static func locateMetallib(
        in roots: [URL],
        fileManager: FileManager
    ) -> URL? {
        let configurations: [String] = ["Debug", "Release"]
        for root in roots {
            let directBundle: URL = root.appendingPathComponent(bundleName, isDirectory: true)
            if let metallib: URL = resolveMetallib(in: directBundle, fileManager: fileManager) {
                return metallib
            }

            for config in configurations {
                let swiftpmBundle: URL = root
                    .appendingPathComponent(".build/Build/Products/\(config)", isDirectory: true)
                    .appendingPathComponent(bundleName, isDirectory: true)
                if let metallib: URL = resolveMetallib(
                    in: swiftpmBundle,
                    fileManager: fileManager
                ) {
                    return metallib
                }

                let buildProductsBundle: URL = root
                    .appendingPathComponent("Build/Products/\(config)", isDirectory: true)
                    .appendingPathComponent(bundleName, isDirectory: true)
                if let metallib: URL = resolveMetallib(
                    in: buildProductsBundle,
                    fileManager: fileManager
                ) {
                    return metallib
                }
            }
        }

        return nil
    }

    private static func resolveMetallib(
        in bundleURL: URL,
        fileManager: FileManager
    ) -> URL? {
        let metallibURL: URL = bundleURL.appendingPathComponent(metallibRelativePath)
        guard fileManager.fileExists(atPath: metallibURL.path) else {
            return nil
        }
        return metallibURL
    }
}
