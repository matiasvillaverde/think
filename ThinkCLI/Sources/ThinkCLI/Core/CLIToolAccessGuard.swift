import Foundation

enum CLIToolAccessGuard {
    static func requireAccess(runtime: CLIRuntime, action: String) throws {
        guard runtime.settings.toolAccess == .allow else {
            throw CLIError.toolAccessDenied(action: action)
        }
    }
}
