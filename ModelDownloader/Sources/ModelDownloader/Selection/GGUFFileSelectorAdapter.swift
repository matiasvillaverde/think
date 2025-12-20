import Abstractions
import Foundation

/// Adapter to make GGUFFileSelector conform to FileSelectorProtocol
internal struct GGUFFileSelectorAdapter: FileSelectorProtocol {
    private let selector: GGUFFileSelector = GGUFFileSelector()

    internal func selectFiles(from files: [ModelFile]) async -> [ModelFile] {
        // Convert ModelFile to FileInfo for the existing selector
        let fileInfos: [FileInfo] = files.map { file in
            FileInfo(
                path: file.path,
                size: file.size ?? 0,
                lfs: nil
            )
        }

        // Use existing selection logic
        let selectedFile: FileInfo? = await selector.selectOptimalFile(from: fileInfos)

        // Convert back to ModelFile array
        if let selectedFile {
            // GGUF selector returns a single optimal file
            return [
                ModelFile(
                    path: selectedFile.path,
                    size: selectedFile.size == 0 ? nil : selectedFile.size,
                    sha: nil
                )
            ]
        }
        return []
    }
}
