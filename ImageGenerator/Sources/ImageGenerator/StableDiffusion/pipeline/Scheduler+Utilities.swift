import Foundation

/// Evenly spaced floats between specified interval
///
/// - Parameters:
///   - start: Start of the interval
///   - end: End of the interval
///   - count: The number of floats to return between [*start*, *end*]
/// - Returns: Float array with *count* elements evenly spaced between at *start* and *end*
func linspace(_ start: Float, _ end: Float, _ count: Int) -> [Float] {
    let scale = (end - start) / Float(count - 1)
    return (0..<count).map { Float($0) * scale + start }
}

extension Collection {
    /// Collection element index from the back. *self[back: 1]* yields the last element
    public subscript(back i: Int) -> Element {
        self[index(endIndex, offsetBy: -i)]
    }
}
