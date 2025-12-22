import Foundation

/// Loads JSON data and normalizes non-standard float literals (e.g. Infinity).
internal func loadJSONData(from url: URL) throws -> Data {
    let data = try Data(contentsOf: url)
    guard let text = String(data: data, encoding: .utf8) else {
        return data
    }

    guard text.contains("Infinity") || text.contains("NaN") else {
        return data
    }

    // Replace non-standard tokens with JSON-compatible numeric literals.
    let sanitized = text
        .replacingOccurrences(of: "-Infinity", with: "-1e30")
        .replacingOccurrences(of: "Infinity", with: "1e30")
        .replacingOccurrences(of: "NaN", with: "0.0")

    return Data(sanitized.utf8)
}
