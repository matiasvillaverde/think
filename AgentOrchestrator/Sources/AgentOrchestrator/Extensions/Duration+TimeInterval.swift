import Foundation

// MARK: - Duration to TimeInterval Conversion

private let kNanosecondsPerSecond: Int64 = 1_000_000_000

extension Duration {
    internal func toTimeInterval() -> TimeInterval {
        // Convert Duration to seconds (TimeInterval is Double representing seconds)
        let totalNanoseconds: Int64 = self.components.seconds * kNanosecondsPerSecond +
            self.components.attoseconds / kNanosecondsPerSecond
        return Double(totalNanoseconds) / Double(kNanosecondsPerSecond)
    }
}
