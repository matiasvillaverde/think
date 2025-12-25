import Foundation

/// Helpers for generating RAG table names.
public enum RagTableName {
    /// Returns the RAG table name for a given chat ID.
    public static func chatTableName(chatId: UUID) -> String {
        let normalizedId: String = chatId.uuidString.replacingOccurrences(of: "-", with: "_")
        return "t_\(normalizedId)"
    }

    /// Returns the RAG table name for memories belonging to a user.
    public static func memoryTableName(userId: UUID) -> String {
        let normalizedId: String = userId.uuidString.replacingOccurrences(of: "-", with: "_")
        return "memory_\(normalizedId)"
    }
}
