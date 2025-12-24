import Abstractions
import Foundation
import UniformTypeIdentifiers

// MARK: - Local Import Helpers

extension MyModelsView {
    enum LocalImportKind {
        case gguf
        case mlx
    }

    enum LocalImportKinds {
        static let ggufTypes: [UTType] = {
            if let ggufType = UTType(filenameExtension: "gguf") {
                return [ggufType]
            }
            return [.data]
        }()

        static let mlxTypes: [UTType] = [UTType.folder, .data]
    }

    func handleImportResult(_ result: Result<[URL], Error>, kind: LocalImportKind) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                setImportErrorMessage(String(localized: "No file selected.", bundle: .module))
                return
            }
            Task {
                await importLocalModel(from: url, kind: kind)
            }

        case .failure(let error):
            setImportErrorMessage(error.localizedDescription)
        }
    }

    private func importLocalModel(from url: URL, kind: LocalImportKind) async {
        let resolved: (URL, SendableModel.Backend) = resolveImportLocation(from: url, kind: kind)
        let resolvedURL: URL = resolved.0
        let backend: SendableModel.Backend = resolved.1
        if let validationError = validateResolvedURL(resolvedURL, kind: kind) {
            setImportErrorMessage(validationError)
            return
        }

        let modelId: UUID? = await createLocalModel(
            name: resolvedURL.deletingPathExtension().lastPathComponent,
            backend: backend,
            resolvedURL: resolvedURL
        )
        if modelId == nil {
            setImportErrorMessage(String(localized: "Failed to add local model.", bundle: .module))
        }
    }

    private func resolveImportLocation(
        from url: URL,
        kind: LocalImportKind
    ) -> (URL, SendableModel.Backend) {
        switch kind {
        case .gguf:
            return (url, .gguf)

        case .mlx:
            let resolvedURL: URL = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
            return (resolvedURL, .mlx)
        }
    }

    private func validateResolvedURL(_ url: URL, kind: LocalImportKind) -> String? {
        var isDirectory: ObjCBool = false
        let exists: Bool = FileManager.default.fileExists(
            atPath: url.path,
            isDirectory: &isDirectory
        )
        if !exists {
            return String(localized: "Selected model location was not found.", bundle: .module)
        }
        if kind == .gguf, isDirectory.boolValue {
            return String(localized: "Please select a .gguf file.", bundle: .module)
        }
        return nil
    }

    private func createLocalModel(
        name: String,
        backend: SendableModel.Backend,
        resolvedURL: URL
    ) async -> UUID? {
        let size: UInt64 = calculateSize(for: resolvedURL)
        let bookmark: Data? = createBookmark(for: resolvedURL)

        return await addLocalModelEntry(
            LocalModelImport(
                name: name,
                backend: backend,
                type: .language,
                parameters: 1,
                ramNeeded: size,
                size: size,
                locationLocal: resolvedURL.path,
                locationBookmark: bookmark
            )
        )
    }

    private func createBookmark(for url: URL) -> Data? {
        #if os(macOS) || os(iOS) || os(visionOS)
        return try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        #else
        return nil
        #endif
    }

    private func calculateSize(for url: URL) -> UInt64 {
        var isDirectory: ObjCBool = false
        let exists: Bool = FileManager.default.fileExists(
            atPath: url.path,
            isDirectory: &isDirectory
        )
        if !exists {
            return 0
        }

        if isDirectory.boolValue {
            let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
            let enumerator: FileManager.DirectoryEnumerator? = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
            var total: UInt64 = 0
            while let fileURL = enumerator?.nextObject() as? URL {
                if let values = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                    values.isRegularFile == true {
                    total += UInt64(values.fileSize ?? 0)
                }
            }
            return total
        }

        if let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            return UInt64(fileSize)
        }
        return 0
    }
}
