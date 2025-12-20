import Abstractions
import Foundation

/// Cache for incremental processing of LLM outputs with UUID consistency
internal actor ProcessingCache {
    private static let maxCacheSize: Int = 100
    private static let channelCacheMultiplier: Int = 3
    private static let channelCacheReductionMultiplier: Int = 2
    private static let contentPrefixLength: Int = 50

    private var cache: [String: [ChannelMessage]] = [:]
    private var contentHashes: [String: String] = [:]
    private var channelIdCache: [String: UUID] = [:]

    func getCachedChannels(for output: String) -> [ChannelMessage] {
        let hash: String = hashString(output)
        if let cachedHash: String = contentHashes[hash],
            let channels: [ChannelMessage] = cache[cachedHash] {
            return channels
        }
        return []
    }

    /// Get or create a UUID for a channel based on its content signature
    func getOrCreateChannelId(for signature: String) -> UUID {
        if let existingId: UUID = channelIdCache[signature] {
            return existingId
        }
        let newId: UUID = UUID()
        channelIdCache[signature] = newId
        return newId
    }

    func update(_ output: String, channels: [ChannelMessage]) {
        let hash: String = hashString(output)
        contentHashes[hash] = hash
        cache[hash] = channels

        // Update channel ID cache with signatures from channels
        for channel in channels {
            let signature: String = createChannelSignature(
                type: channel.type,
                order: channel.order,
                contentPrefix: channel.content,
                recipient: channel.recipient
            )
            channelIdCache[signature] = channel.id
        }

        // Limit cache size
        if cache.count > Self.maxCacheSize {
            // Remove oldest entries
            let toRemove: Int = cache.count - Self.maxCacheSize
            for (key, _) in cache.prefix(toRemove) {
                cache.removeValue(forKey: key)
                contentHashes.removeValue(forKey: key)
            }

            // Clean up channel ID cache if it gets too large
            let maxChannelCache: Int = Self.maxCacheSize * Self.channelCacheMultiplier
            if channelIdCache.count > maxChannelCache {
                let targetSize: Int = Self.maxCacheSize * Self.channelCacheReductionMultiplier
                let excess: Int = channelIdCache.count - targetSize
                for (key, _) in channelIdCache.prefix(excess) {
                    channelIdCache.removeValue(forKey: key)
                }
            }
        }
    }

    private func hashString(_ string: String) -> String {
        // Simple hash for now
        String(string.hashValue)
    }

    /// Create a stable signature for a channel that survives content streaming
    private func createChannelSignature(
        type: ChannelMessage.ChannelType,
        order: Int,
        contentPrefix: String,
        recipient: String?
    ) -> String {
        let stablePrefix: String = String(contentPrefix.prefix(Self.contentPrefixLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let recipientPart: String = recipient ?? ""
        return "\(type.rawValue):\(order):\(stablePrefix.hashValue):\(recipientPart)"
    }
}
