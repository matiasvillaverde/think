import Foundation
import SwiftData
import Abstractions

/// Represents a file associated with a model
@Model
public final class ModelFile {
    // MARK: - Properties

    @Attribute()
    public internal(set) var name: String

    @Attribute()
    public internal(set) var size: Int64?

    @Attribute()
    public internal(set) var quantization: String?

    // MARK: - Relationships

    public internal(set) var model: Model?

    // MARK: - Initialization

    init(name: String, size: Int64? = nil, quantization: String? = nil) {
        self.name = name
        self.size = size
        self.quantization = quantization
    }

    /// Create ModelFile from Abstractions ModelFile
    convenience init(from abstractionFile: Abstractions.ModelFile) {
        // Use the robust quantization detection from Abstractions
        let quantization = QuantizationLevel.detectFromFilename(abstractionFile.filename)?.rawValue

        self.init(
            name: abstractionFile.filename,
            size: abstractionFile.size,
            quantization: quantization
        )
    }
}

// MARK: - Computed Properties

extension ModelFile {
    /// Formatted file size string
    public var formattedSize: String {
        guard let size = size else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
