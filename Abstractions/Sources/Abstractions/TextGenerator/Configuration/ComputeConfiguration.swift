import Foundation

/// Configuration for compute resources used by LLM inference
public struct ComputeConfiguration: Sendable, Equatable {
    /// The maximum context size in tokens
    public let contextSize: Int

    /// The batch size for processing tokens
    public let batchSize: Int

    /// The number of threads to use for computation
    public let threadCount: Int

    /// Initialize compute configuration with specific values
    /// - Parameters:
    ///   - contextSize: The maximum context size in tokens
    ///   - batchSize: The batch size for processing tokens
    ///   - threadCount: The number of threads to use for computation
    public init(
        contextSize: Int,
        batchSize: Int,
        threadCount: Int
    ) {
        self.contextSize = contextSize
        self.batchSize = batchSize
        self.threadCount = threadCount
    }
}

// MARK: - Convenience Configurations

extension ComputeConfiguration {
    /// Small configuration suitable for testing and lightweight models
    public static let small = ComputeConfiguration(
        contextSize: 512,
        batchSize: 8,
        threadCount: 4
    )

    /// Medium configuration suitable for standard usage
    public static let medium = ComputeConfiguration(
        contextSize: 2048,
        batchSize: 512,
        threadCount: 8
    )

    /// Large configuration suitable for production workloads
    public static let large = ComputeConfiguration(
        contextSize: 4096,
        batchSize: 1024,
        threadCount: 16
    )
}
