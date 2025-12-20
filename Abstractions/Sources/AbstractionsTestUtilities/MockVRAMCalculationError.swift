import Foundation

/// Mock error for testing VRAMCalculator failures
public enum MockVRAMCalculationError: Error {
    case integerOverflow(String)
}
