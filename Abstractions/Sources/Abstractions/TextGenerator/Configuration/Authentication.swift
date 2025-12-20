/// Authentication methods for different providers.
public enum Authentication: Sendable {
    /// No authentication required (typical for local models).
    case noAuth

    /// API key authentication (most common for cloud providers).
    /// The key is typically sent as "Authorization: Bearer <key>" or similar.
    case apiKey(String)
}
