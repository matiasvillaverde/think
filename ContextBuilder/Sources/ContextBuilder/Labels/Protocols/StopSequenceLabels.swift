import Foundation

/// Labels defining stop sequences for generation
internal protocol StopSequenceLabels {
    /// Set of sequences that should stop generation
    var stopSequence: Set<String?> { get }
}
