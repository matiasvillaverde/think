import Foundation

/// How to split model across multiple GPUs
public enum SplitMode: String, Sendable, CaseIterable {
    /// No splitting, use single GPU
    case noSplit = "None"

    /// Split by layers across GPUs
    case layer = "Layer"

    /// Split by rows (tensor parallelism)
    case row = "Row"

    /// Default split mode
    public static let `default`: SplitMode = .layer
}
