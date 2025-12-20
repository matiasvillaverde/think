import Abstractions
import Foundation

/// Detects and extracts quantization information from model files
///
/// This component is responsible for identifying different quantization
/// variants within a model repository, particularly for GGUF models
/// that often contain multiple quantization options.
public struct QuantizationDetector: Sendable {
    private let vramCalculator: VRAMCalculatorProtocol

    public init(vramCalculator: VRAMCalculatorProtocol = VRAMCalculator()) {
        self.vramCalculator = vramCalculator
    }

    /// Detect all quantization variants in a model
    /// - Parameters:
    ///   - model: The discovered model
    ///   - parameters: Optional parameter count for accurate calculations
    /// - Returns: Array of quantization info for all variants found
    @preconcurrency
    @MainActor
    public func detectQuantizations(
        in model: DiscoveredModel,
        parameters: UInt64? = nil
    ) -> [QuantizationInfo] {
        var quantizations: [QuantizationInfo] = []

        // Extract parameter count from model name if not provided
        let effectiveParameters: UInt64? = parameters ?? extractParameters(from: model)

        // Process each file
        for file in model.files {
            // Skip non-model files
            guard file.isModelFile else { continue }

            // Try to create quantization info from the file
            if let quantInfo = QuantizationInfo.from(
                file: file,
                calculator: vramCalculator,
                parameters: effectiveParameters
            ) {
                quantizations.append(quantInfo)
            }
        }

        // Sort by quality (highest first)
        quantizations.sort(by: QuantizationInfo.byQuality)

        // Mark recommended quantizations if none are already marked
        if !quantizations.contains(where: \.isRecommended) {
            quantizations = markRecommendedQuantizations(quantizations)
        }

        return quantizations
    }

    /// Extract parameter count from model name and metadata
    @MainActor
    private func extractParameters(from model: DiscoveredModel) -> UInt64? {
        // Try to extract from model name
        if let params = ModelParameters.fromString(model.name) {
            return params.count
        }

        // Try to extract from model ID
        let idComponents: [Substring] = model.id.split(separator: "/")
        if let modelName = idComponents.last {
            if let params = ModelParameters.fromString(String(modelName)) {
                return params.count
            }
        }

        // Try to find in tags
        for tag in model.tags where ModelParameters.fromString(tag) != nil {
            if let params = ModelParameters.fromString(tag) {
                return params.count
            }
        }

        // Try to extract from model card if available
        if let modelCard = model.modelCard {
            return extractParametersFromModelCard(modelCard)
        }

        return nil
    }

    /// Extract parameters from model card content
    private func extractParametersFromModelCard(_ content: String) -> UInt64? {
        // Common patterns in model cards
        let patterns: [String] = [
            #"(\d+\.?\d*)[Bb]\s*(?:parameters?|params?)"#,
            #"(?:parameters?|params?):\s*(\d+\.?\d*)[Bb]"#,
            #"(?:model\s+size|size):\s*(\d+\.?\d*)[Bb]"#
        ]

        for pattern in patterns {
            if let regex: NSRegularExpression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range: NSRange = NSRange(content.startIndex..<content.endIndex, in: content)
                if let match = regex.firstMatch(in: content, options: [], range: range) {
                    if let numberRange = Range(match.range(at: 1), in: content) {
                        let numberStr: String = String(content[numberRange])
                        if let value = Double(numberStr) {
                            return UInt64(value * 1_000_000_000)
                        }
                    }
                }
            }
        }

        return nil
    }

    /// Mark recommended quantizations based on balance of quality and size
    private func markRecommendedQuantizations(_ quantizations: [QuantizationInfo]) -> [QuantizationInfo] {
        guard !quantizations.isEmpty else { return quantizations }

        var updated: [QuantizationInfo] = quantizations

        // Find the "sweet spot" quantizations
        let sweetSpotLevels: Set<QuantizationLevel> = [.q4_k_m, .q5_k_m, .int4, .fp16]

        // Mark the first sweet spot quantization as recommended
        for (index, quant) in updated.enumerated() where sweetSpotLevels.contains(quant.level) {
            updated[index] = QuantizationInfo(
                level: quant.level,
                fileSize: quant.fileSize,
                fileName: quant.fileName,
                sha: quant.sha,
                memoryRequirements: quant.memoryRequirements,
                isRecommended: true
            )
            break
        }

        // If no sweet spot found, mark the middle quality one
        if !updated.contains(where: \.isRecommended), !updated.isEmpty {
            let middleIndex: Int = updated.count / 2
            let middle: QuantizationInfo = updated[middleIndex]
            updated[middleIndex] = QuantizationInfo(
                level: middle.level,
                fileSize: middle.fileSize,
                fileName: middle.fileName,
                sha: middle.sha,
                memoryRequirements: middle.memoryRequirements,
                isRecommended: true
            )
        }

        return updated
    }

    // MARK: - Backend-Specific Detection

    /// Detect GGUF-specific quantizations
    public func detectGGUFQuantizations(in files: [ModelFile]) -> [QuantizationInfo] {
        files.compactMap { file in
            guard file.fileExtension == "gguf",
                  let level = QuantizationLevel.detectFromFilename(file.filename),
                  let size = file.size else {
                return nil
            }

            let memReq: MemoryRequirements = vramCalculator.estimateFromFileSize(
                fileSize: UInt64(size),
                quantization: level,
                overheadPercentage: 0.25
            )

            return QuantizationInfo(
                level: level,
                fileSize: UInt64(size),
                fileName: file.filename,
                sha: file.sha,
                memoryRequirements: memReq,
                isRecommended: false
            )
        }
    }

    /// Group quantizations by backend
    public func groupByBackend(
        _ quantizations: [QuantizationInfo],
        for _: DiscoveredModel
    ) -> [SendableModel.Backend: [QuantizationInfo]] {
        var grouped: [SendableModel.Backend: [QuantizationInfo]] = [:]

        for quant in quantizations {
            guard let fileName = quant.fileName else { continue }

            // Determine backend from file extension
            let backend: SendableModel.Backend
            if fileName.hasSuffix(".gguf") {
                backend = .gguf
            } else if fileName.hasSuffix(".mlpackage") || fileName.hasSuffix(".mlmodel") {
                backend = .coreml
            } else if fileName.hasSuffix(".safetensors") || fileName.hasSuffix(".bin") {
                backend = .mlx
            } else {
                continue
            }

            if grouped[backend] == nil {
                grouped[backend] = []
            }
            grouped[backend]?.append(quant)
        }

        return grouped
    }
}
