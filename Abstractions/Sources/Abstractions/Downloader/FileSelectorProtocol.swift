import Foundation

/// Protocol for selecting optimal files from a model repository
///
/// Implementations of this protocol define format-specific rules for
/// selecting which files should be downloaded from a model repository.
/// This ensures consistency between file size calculations during
/// discovery and actual downloads.
///
/// Example implementations:
/// - `CoreMLFileSelector`: Selects optimal CoreML variants (split-einsum vs original)
/// - `GGUFFileSelector`: Selects best quantization for available memory
public protocol FileSelectorProtocol: Sendable {
    /// Select optimal files based on format-specific rules
    /// - Parameter files: All files available in the model repository
    /// - Returns: Subset of files that should be downloaded
    func selectFiles(from files: [ModelFile]) async -> [ModelFile]
}
