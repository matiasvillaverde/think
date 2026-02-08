import CryptoKit
import Foundation

internal struct OpenClawConnectTextContext: Sendable {
    internal let connectId: String
    internal let platform: String
    internal let attempt: OpenClawConnectAttempt
    internal let identity: OpenClawDeviceIdentity
    internal let privateKey: Curve25519.Signing.PrivateKey
    internal let signedAtMs: Int64
    internal let nonce: String?
}
