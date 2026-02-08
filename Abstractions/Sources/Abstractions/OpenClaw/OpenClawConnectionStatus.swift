import Foundation

public enum OpenClawConnectionStatus: Sendable, Equatable, Codable {
    case idle
    case connecting
    case connected
    case pairingRequired(requestId: String)
    case failed(message: String)

    public var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}
