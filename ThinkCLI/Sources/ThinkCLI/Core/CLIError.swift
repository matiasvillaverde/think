import Foundation

enum CLIExitCode: Int32, Sendable {
    case success = 0
    case failure = 1
    case usage = 64
    case data = 65
    case unavailable = 69
    case software = 70
    case permission = 77
}

struct CLIError: Error, LocalizedError, Sendable {
    let message: String
    let exitCode: CLIExitCode

    var errorDescription: String? {
        message
    }

    static func toolAccessDenied(action: String) -> CLIError {
        CLIError(
            message: "Tool access denied for \(action). Use --tool-access allow to enable.",
            exitCode: .permission
        )
    }
}
