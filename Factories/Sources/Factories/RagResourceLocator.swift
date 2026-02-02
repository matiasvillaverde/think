import Foundation

internal enum RagResourceLocator {
    #if os(iOS) || os(visionOS)
    internal static let modelDirectoryName: String = "Resources-ios/all-MiniLM-L6-v2"
    #else
    internal static let modelDirectoryName: String = "Resources-macos/all-MiniLM-L6-v2"
    #endif

    internal static let requiredFiles: [String] = [
        "config.json",
        "tokenizer.json",
        "model.safetensors"
    ]

    internal static func locateModelDirectory(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        additionalSearchRoots: [URL] = []
    ) -> URL? {
        var roots: [URL] = []
        if let resourceURL = bundle.resourceURL {
            roots.append(resourceURL)
        }
        if let execURL = bundle.executableURL?.deletingLastPathComponent() {
            roots.append(execURL)
        }
        roots.append(URL(fileURLWithPath: fileManager.currentDirectoryPath))
        roots.append(contentsOf: additionalSearchRoots)

        var seen: Set<String> = []
        let uniqueRoots: [URL] = roots.filter { seen.insert($0.path).inserted }

        for root in uniqueRoots {
            let candidate: URL = root.appendingPathComponent(modelDirectoryName, isDirectory: true)
            if hasRequiredFiles(at: candidate, fileManager: fileManager) {
                return candidate
            }
        }

        return nil
    }

    private static func hasRequiredFiles(
        at directory: URL,
        fileManager: FileManager
    ) -> Bool {
        for file in requiredFiles {
            let fileURL: URL = directory.appendingPathComponent(file)
            if !fileManager.fileExists(atPath: fileURL.path) {
                return false
            }
        }
        return true
    }
}
