import Foundation

internal enum CalculatorError: Error, LocalizedError {
    case divisionByZero
    case invalidParameters(String)
    case unknownOperation(String)

    internal var errorDescription: String? {
        switch self {
        case .divisionByZero:
            return "Division by zero"

        case .invalidParameters(let message):
            return "Invalid parameters: \(message)"

        case .unknownOperation(let operation):
            return "Unknown operation: \(operation)"
        }
    }
}
