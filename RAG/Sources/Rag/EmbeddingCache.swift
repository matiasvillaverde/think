import CryptoKit
import Foundation

internal struct EmbeddingCacheKey: Hashable, Sendable {
    let modelKey: ModelConfigurationKey
    let textHash: String
}

internal enum EmbeddingCacheError: Error, LocalizedError, Equatable {
    case unexpectedEmbeddingCount(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case let .unexpectedEmbeddingCount(expected: expected, actual: actual):
            return "Expected \(expected) embeddings but received \(actual)"
        }
    }
}

internal actor EmbeddingCache {
    private let maxEntries: Int
    private var entries: [EmbeddingCacheKey: [Float]] = [:]
    private var order: [EmbeddingCacheKey] = []

    init(maxEntries: Int) {
        self.maxEntries = max(0, maxEntries)
    }

    func embeddings(
        texts: [String],
        modelKey: ModelConfigurationKey,
        compute: @Sendable ([String]) async throws -> [[Float]]
    ) async throws -> [[Float]] {
        guard !texts.isEmpty else {
            return []
        }

        var results: [[Float]] = Array(repeating: [], count: texts.count)
        var missingTexts: [String] = []
        var missingOrder: [EmbeddingCacheKey] = []
        var missingIndices: [EmbeddingCacheKey: [Int]] = [:]

        for (index, text) in texts.enumerated() {
            let key: EmbeddingCacheKey = EmbeddingCacheKey(
                modelKey: modelKey,
                textHash: Self.hash(text)
            )

            if let cached = entries[key] {
                results[index] = cached
                touch(key)
            } else if var indices = missingIndices[key] {
                indices.append(index)
                missingIndices[key] = indices
            } else {
                missingTexts.append(text)
                missingOrder.append(key)
                missingIndices[key] = [index]
            }
        }

        guard !missingTexts.isEmpty else {
            return results
        }

        let computed: [[Float]] = try await compute(missingTexts)
        guard computed.count == missingTexts.count else {
            throw EmbeddingCacheError.unexpectedEmbeddingCount(
                expected: missingTexts.count,
                actual: computed.count
            )
        }

        for (offset, key) in missingOrder.enumerated() {
            let embedding: [Float] = computed[offset]
            let indices: [Int] = missingIndices[key] ?? []
            for index in indices {
                results[index] = embedding
            }
            store(key, embedding: embedding)
        }

        return results
    }

    private func touch(_ key: EmbeddingCacheKey) {
        guard maxEntries > 0 else {
            return
        }

        if let index = order.firstIndex(of: key) {
            order.remove(at: index)
        }
        order.append(key)
    }

    private func store(_ key: EmbeddingCacheKey, embedding: [Float]) {
        guard maxEntries > 0 else {
            return
        }

        entries[key] = embedding
        touch(key)
        evictIfNeeded()
    }

    private func evictIfNeeded() {
        while entries.count > maxEntries, let oldest = order.first {
            order.removeFirst()
            entries.removeValue(forKey: oldest)
        }
    }

    private static func hash(_ text: String) -> String {
        let digest: SHA256.Digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
