import Abstractions
import Foundation

/// Adapter to make MLXFileSelector conform to FileSelectorProtocol
internal struct MLXFileSelectorAdapter: FileSelectorProtocol {
    private let selector: MLXFileSelector = MLXFileSelector()

    internal func selectFiles(from files: [ModelFile]) async -> [ModelFile] {
        await selector.selectFiles(from: files)
    }
}
