import Foundation

/// Represents different quantization levels for AI models
public enum QuantizationLevel: String, Codable, Sendable, CaseIterable {
    /// 32-bit floating point (highest precision)
    case fp32 = "FP32"
    /// 16-bit floating point
    case fp16 = "FP16"
    /// 8-bit integer
    case int8 = "INT8"
    /// 4-bit integer (highest compression)
    case int4 = "INT4"

    /// Quantization-specific variants for GGUF models
    /// These follow the naming conventions from llama.cpp (https://github.com/ggerganov/llama.cpp)
    case q2_k = "Q2_K"
    case q3_k_s = "Q3_K_S"
    case q3_k_m = "Q3_K_M"
    case q3_k_l = "Q3_K_L"
    case q4_0 = "Q4_0"
    case q4_1 = "Q4_1"
    case q4_k_s = "Q4_K_S"
    case q4_k_m = "Q4_K_M"
    case q5_0 = "Q5_0"
    case q5_1 = "Q5_1"
    case q5_k_s = "Q5_K_S"
    case q5_k_m = "Q5_K_M"
    case q6_k = "Q6_K"
    case q8_0 = "Q8_0"

    /// Bits per parameter for this quantization level
    public var bitsPerParameter: Double {
        switch self {
        case .fp32: return 32
        case .fp16: return 16
        case .int8, .q8_0: return 8
        case .int4: return 4
        case .q2_k: return 2.5625
        case .q3_k_s: return 2.9375
        case .q3_k_m: return 3.4375
        case .q3_k_l: return 3.5625
        case .q4_0, .q4_1: return 4.5
        case .q4_k_s, .q4_k_m: return 4.625
        case .q5_0, .q5_1: return 5.5
        case .q5_k_s, .q5_k_m: return 5.625
        case .q6_k: return 6.5625
        }
    }

    /// Human-readable description
    public var displayName: String {
        switch self {
        case .fp32: return "32-bit Float"
        case .fp16: return "16-bit Float"
        case .int8: return "8-bit Integer"
        case .int4: return "4-bit Integer"
        default: return rawValue
        }
    }

    /// Quality level (1.0 = highest, 0.0 = lowest)
    public var qualityLevel: Double {
        switch self {
        case .fp32: return 1.0
        case .fp16: return 0.9
        case .int8, .q8_0: return 0.7
        case .q6_k: return 0.6
        case .q5_k_m, .q5_k_s, .q5_1, .q5_0: return 0.5
        case .q4_k_m, .q4_k_s, .q4_1, .q4_0, .int4: return 0.4
        case .q3_k_l, .q3_k_m, .q3_k_s: return 0.3
        case .q2_k: return 0.2
        }
    }
}

// MARK: - Quantization Detection

public extension QuantizationLevel {
    /// Detect quantization level from filename
    /// - Parameter filename: The model filename
    /// - Returns: Detected quantization level or nil
    static func detectFromFilename(_ filename: String) -> QuantizationLevel? {
        let lowercased = filename.lowercased()

        // Check GGUF patterns first
        if let ggufLevel = detectGGUFQuantization(lowercased) {
            return ggufLevel
        }

        // Check generic patterns
        return detectGenericQuantization(lowercased)
    }

    private static func detectGGUFQuantization(_ lowercased: String) -> QuantizationLevel? {
        let ggufPatterns: [(String, QuantizationLevel)] = [
            ("q2_k", .q2_k),
            ("q3_k_s", .q3_k_s),
            ("q3_k_m", .q3_k_m),
            ("q3_k_l", .q3_k_l),
            ("q4_0", .q4_0),
            ("q4_1", .q4_1),
            ("q4_k_s", .q4_k_s),
            ("q4_k_m", .q4_k_m),
            ("q5_0", .q5_0),
            ("q5_1", .q5_1),
            ("q5_k_s", .q5_k_s),
            ("q5_k_m", .q5_k_m),
            ("q6_k", .q6_k),
            ("q8_0", .q8_0)
        ]

        for (pattern, level) in ggufPatterns {
            if lowercased.contains(pattern) {
                return level
            }
        }
        return nil
    }

    private static func detectGenericQuantization(_ lowercased: String) -> QuantizationLevel? {
        if lowercased.contains("fp32") || lowercased.contains("f32") {
            return .fp32
        }
        if lowercased.contains("fp16") || lowercased.contains("f16") {
            return .fp16
        }
        if lowercased.contains("int8") || lowercased.contains("8bit") {
            return .int8
        }
        if lowercased.contains("int4") || lowercased.contains("4bit") {
            return .int4
        }
        return nil
    }
}
