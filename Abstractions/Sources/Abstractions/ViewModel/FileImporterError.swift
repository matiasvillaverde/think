import Foundation

/// Error types related to file importing operations
public enum FileImporterError: Error {
    /// Access to the file was denied
    case accessDenied

    /// Localized description of the error
    public var localizedDescription: String {
        switch self {
        case .accessDenied:
            return String(localized: "Access to the file was denied", bundle: .module)
        }
    }
}
