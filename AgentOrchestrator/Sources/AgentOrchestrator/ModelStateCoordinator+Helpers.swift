import Abstractions
import Foundation

// MARK: - Helper Methods for ModelStateCoordinator
extension ModelStateCoordinator {
    internal func getBatchSizeForAppleSilicon() -> Int {
        let totalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory

        let eightGB: UInt64 = 8_000_000_000
        let sixteenGB: UInt64 = 16_000_000_000
        let thirtyTwoGB: UInt64 = 32_000_000_000

        let smallBatch: Int = 512
        let mediumBatch: Int = 1_024
        let largeBatch: Int = 2_048
        let extraLargeBatch: Int = 4_096

        switch totalMemory {
        case ..<eightGB:          // < 8GB
            return smallBatch
        case ..<sixteenGB:        // < 16GB
            return mediumBatch
        case ..<thirtyTwoGB:      // < 32GB
            return largeBatch
        default:                   // >= 32GB
            return extraLargeBatch
        }
    }

    internal func resolveModelLocation(sendableModel: SendableModel) async throws -> URL {
        guard !sendableModel.location.isEmpty else {
            Self.logger.error("Model location is empty for model: \(sendableModel.id)")
            throw ModelStateCoordinatorError.emptyModelLocation
        }

        // Resolve the HuggingFace repository ID to a local path
        guard let localPath = await modelDownloader.getModelLocation(for: sendableModel.location) else {
            Self.logger.error("Model not found locally: \(sendableModel.location)")
            throw ModelStateCoordinatorError.modelNotDownloaded(sendableModel.location)
        }

        Self.logger.info("Resolved model location: \(sendableModel.location) -> \(localPath.path)")

        return localPath
    }
}
