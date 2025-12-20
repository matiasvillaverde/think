import CoreML
import OSLog

extension MLTensor {
    func convertTensorToVectors() async throws -> [[Float]] {
        let logger: Logger = Logger(subsystem: "RAG", category: "MLTensor")
        logger.debug("Starting conversion of MLTensor to vector array.")

        let shaped: MLShapedArray<Float> = await self.shapedArray(of: Float.self)
        let shape: [Int] = shaped.shape
        logger.debug("Tensor shape: \(shape)")

        guard !shape.isEmpty else {
            throw MLTensorError.embeddingConversionFailed("Tensor shape is empty")
        }

        let numChunks: Int = shape[0]
        let vectorSize: Int = shape.dropFirst().reduce(1, *)
        logger.debug("Tensor dimensions: \(numChunks) chunks, each with size \(vectorSize)")

        let scalars: [Float] = shaped.scalars
        logger.debug("Total scalars count in tensor: \(scalars.count)")

        guard scalars.count == numChunks * vectorSize else {
            throw MLTensorError.embeddingConversionFailed("Scalar count mismatch")
        }

        var vectors: [[Float]] = [[Float]]()
        vectors.reserveCapacity(numChunks)

        for chunkIndex in 0..<numChunks {
            let start: Int = chunkIndex * vectorSize
            let end: Int = start + vectorSize
            vectors.append(Array(scalars[start..<end]))
            logger.debug("Extracted vector \(chunkIndex + 1)/\(numChunks)")
        }

        return vectors
    }

    func convertTensorToVector() async throws -> [Float] {
        let shaped: MLShapedArray<Float> = await self.shapedArray(of: Float.self)
        return Array(shaped.scalars)
    }

    public enum MLTensorError: Error, LocalizedError, Equatable {
        case embeddingConversionFailed(String)

        public var errorDescription: String? {
            switch self {
            case .embeddingConversionFailed(let details):
                return "Failed to convert embedding: \(details)"
            }
        }
    }
}
