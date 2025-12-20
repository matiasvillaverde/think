import Foundation

/// Result of model compatibility validation
public struct ValidationResult: Sendable {
    public let isValid: Bool
    public let warnings: [String]

    public init(isValid: Bool, warnings: [String]) {
        self.isValid = isValid
        self.warnings = warnings
    }
}
