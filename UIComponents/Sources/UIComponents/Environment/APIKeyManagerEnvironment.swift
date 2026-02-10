import RemoteSession
import SwiftUI

internal enum APIKeyManagerEnvironment {}

private struct APIKeyManagerEnvironmentKey: EnvironmentKey {
    static let defaultValue: any APIKeyManaging = APIKeyManager.shared
}

extension EnvironmentValues {
    var apiKeyManager: APIKeyManaging {
        get { self[APIKeyManagerEnvironmentKey.self] }
        set { self[APIKeyManagerEnvironmentKey.self] = newValue }
    }
}
