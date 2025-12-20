import Abstractions
import Foundation

/// Adapter to make CoreMLFileSelector conform to FileSelectorProtocol
internal struct CoreMLFileSelectorAdapter: FileSelectorProtocol {
    private let selector: CoreMLFileSelector = CoreMLFileSelector()

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
        let selectedFileInfos: [FileInfo] = await selector.selectFiles(from: fileInfos)

        // Convert back to ModelFile
        return selectedFileInfos.map { fileInfo in
            ModelFile(
                path: fileInfo.path,
                size: fileInfo.size == 0 ? nil : fileInfo.size,
                sha: nil
            )
        }
    }
}
