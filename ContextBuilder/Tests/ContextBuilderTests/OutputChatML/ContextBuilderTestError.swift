import Foundation

internal enum ContextBuilderTestError: Error, LocalizedError {
    case resourceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let resource):
            "Test resource not found: \(resource)"
        }
    }
}
