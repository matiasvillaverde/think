import Foundation

/// Labels for commentary/annotation sections
internal protocol CommentaryLabels {
    /// Label marking the start of commentary
    var commentaryStartLabel: String { get }

    /// Label marking the end of commentary
    var commentaryEndLabel: String { get }
}
