import Foundation

/// Represents where a model's files are sourced from.
public enum ModelLocationKind: String, Codable, Equatable, Sendable, Hashable {
    /// Model files are downloaded from HuggingFace into app-managed storage.
    case huggingFace = "huggingFace"
    /// Model files live at a user-selected local path (not copied).
    case localFile = "localFile"
}
