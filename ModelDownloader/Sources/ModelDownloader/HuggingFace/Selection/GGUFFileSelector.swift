import Abstractions
import Foundation

/// Selects optimal GGUF file based on device capabilities
internal actor GGUFFileSelector {
    private let logger: ModelDownloaderLogger = ModelDownloaderLogger(
        subsystem: "com.think.modeldownloader",
        category: "GGUFFileSelector"
    )

    /// Initialize GGUF file selector
    internal init() {}

    /// Select the best GGUF file from available options
    /// - Parameters:
    ///   - files: Available GGUF files from repository
    ///   - specifiedFilename: Optional specific filename to select
    /// - Returns: Single selected file, or nil if none suitable
    internal func selectOptimalFile(
        from files: [FileInfo],
        specifiedFilename: String? = nil
    ) async -> FileInfo? {
        // Filter to only GGUF files
        let ggufFiles: [FileInfo] = files.filter { $0.path.hasSuffix(".gguf") }

        guard !ggufFiles.isEmpty else {
            await logger.warning("No GGUF files found in repository")
            return nil
        }

        // If specific filename is requested, try to find it
        if let specifiedFilename {
            if let specificFile = ggufFiles.first(where: { $0.path.contains(specifiedFilename) }) {
                await logger.info("Selected specified GGUF file: \(specificFile.path)")
                return specificFile
            }
            await logger.warning("Specified GGUF file '\(specifiedFilename)' not found")
            return nil
        }

        // Automatic selection based on device capabilities
        return await selectBasedOnDeviceCapabilities(from: ggufFiles)
    }

    // MARK: - Private Selection Logic

    private func selectBasedOnDeviceCapabilities(from ggufFiles: [FileInfo]) async -> FileInfo? {
        let deviceMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
        let memoryTier: MemoryTier = determineMemoryTier(for: deviceMemory)

        await logger.info("Device memory: \(formatBytes(Int64(deviceMemory))), tier: \(memoryTier)")

        // Parse and categorize GGUF files by quantization
        let categorizedFiles: [QuantizationType: [FileInfo]] = categorizeGGUFFiles(ggufFiles)

        // Select optimal quantization based on memory tier
        let selectedFile: FileInfo? = selectOptimalQuantization(
            from: categorizedFiles,
            memoryTier: memoryTier
        )

        if let selectedFile {
            await logger.info(
                "Selected optimal GGUF file: \(selectedFile.path) (size: \(formatBytes(selectedFile.size)))"
            )
        } else {
            await logger.warning("No suitable GGUF file found for device capabilities")
        }

        return selectedFile
    }

    private func determineMemoryTier(for physicalMemory: UInt64) -> MemoryTier {
        let gigabytes: UInt64 = physicalMemory / (1_024 * 1_024 * 1_024)

        if gigabytes >= 32 {
            return .high
        }
        if gigabytes >= 16 {
            return .medium
        }
        return .low
    }

    private func categorizeGGUFFiles(_ files: [FileInfo]) -> [QuantizationType: [FileInfo]] {
        var categorized: [QuantizationType: [FileInfo]] = [:]

        for file in files {
            let quantType: QuantizationType = parseQuantizationType(from: file.path)
            if categorized[quantType] == nil {
                categorized[quantType] = []
            }
            categorized[quantType]?.append(file)
        }

        return categorized
    }

    private func parseQuantizationType(from filename: String) -> QuantizationType {
        let uppercased: String = filename.uppercased()

        // Check for specific quantization patterns
        if uppercased.contains("F16") || uppercased.contains("FP16") {
            return .f16
        }
        if uppercased.contains("Q8_0") {
            return .q8_0
        }
        if uppercased.contains("Q6_K") {
            return .q6_k
        }
        if uppercased.contains("Q5_K_M") {
            return .q5_k_m
        }
        if uppercased.contains("Q4_K_M") {
            return .q4_k_m
        }
        if uppercased.contains("Q4_0") {
            return .q4_0
        }
        if uppercased.contains("IQ4_XS") {
            return .iq4_xs
        }
        if uppercased.contains("IQ3_M") {
            return .iq3_m
        }
        return .unknown
    }

    private func selectOptimalQuantization(
        from categorized: [QuantizationType: [FileInfo]],
        memoryTier: MemoryTier
    ) -> FileInfo? {
        let preferredTypes: [QuantizationType] = getPreferredQuantizationTypes(for: memoryTier)

        // Try to find files in order of preference
        for quantType in preferredTypes {
            if let files = categorized[quantType], !files.isEmpty {
                // Return the first file of this quantization type
                // Could be enhanced to select based on file size if multiple variants exist
                return files.first
            }
        }

        // Fallback: return the smallest available file
        return categorized.values.flatMap(\.self).min { $0.size < $1.size }
    }

    private func getPreferredQuantizationTypes(for memoryTier: MemoryTier) -> [QuantizationType] {
        switch memoryTier {
        case .high:
            // High-end devices: prefer quality
            return [.q6_k, .q8_0, .q5_k_m, .q4_k_m, .f16, .q4_0, .iq4_xs, .iq3_m]

        case .medium:
            // Mid-range devices: balanced performance
            return [.q4_k_m, .q5_k_m, .q4_0, .q6_k, .iq4_xs, .iq3_m, .q8_0]

        case .low:
            // Low-memory devices: prioritize efficiency
            return [.iq3_m, .iq4_xs, .q4_0, .q4_k_m, .q5_k_m, .q6_k]
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Supporting Types

private enum MemoryTier {
    case low    // < 16GB
    case medium // 16-32GB
    case high   // 32GB+
}

private enum QuantizationType: CaseIterable {
    case f16
    case q8_0 // swiftlint:disable:this identifier_name
    case q6_k // swiftlint:disable:this identifier_name
    case q5_k_m // swiftlint:disable:this identifier_name
    case q4_k_m // swiftlint:disable:this identifier_name
    case q4_0 // swiftlint:disable:this identifier_name
    case iq4_xs // swiftlint:disable:this identifier_name
    case iq3_m // swiftlint:disable:this identifier_name
    case unknown
}
