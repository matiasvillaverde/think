import Foundation

/// Incremental detector for stop sequences during generation.
internal struct StopSequenceDetector: Sendable {
    private let sequences: [String]
    private let maxSequenceLength: Int
    private var tail: String = ""

    internal init(sequences: [String]) {
        let filtered = sequences.filter { !$0.isEmpty }
        self.sequences = filtered
        self.maxSequenceLength = filtered.map { $0.count }.max() ?? 0
    }

    internal mutating func append(_ text: String) -> Bool {
        guard !sequences.isEmpty, !text.isEmpty else { return false }
        let combined = tail + text
        for sequence in sequences where combined.range(of: sequence) != nil {
            return true
        }
        if maxSequenceLength > 1 {
            tail = String(combined.suffix(maxSequenceLength - 1))
        } else {
            tail = ""
        }
        return false
    }
}
