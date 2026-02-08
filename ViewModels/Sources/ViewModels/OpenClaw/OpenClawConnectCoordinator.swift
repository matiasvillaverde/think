import CryptoKit
import Foundation

internal actor OpenClawConnectCoordinator {
    internal let transport: OpenClawWebSocketTransporting
    internal let connectId: String
    internal let platform: String
    internal let attempt: OpenClawConnectAttempt
    internal let identity: OpenClawDeviceIdentity
    internal let privateKey: Curve25519.Signing.PrivateKey
    internal let clockMs: @Sendable () -> Int64

    private var connectSent: Bool = false
    private var connectNonce: String?

    internal init(
        transport: OpenClawWebSocketTransporting,
        connectId: String,
        platform: String,
        attempt: OpenClawConnectAttempt,
        identity: OpenClawDeviceIdentity,
        privateKey: Curve25519.Signing.PrivateKey,
        clockMs: @escaping @Sendable () -> Int64
    ) {
        self.transport = transport
        self.connectId = connectId
        self.platform = platform
        self.attempt = attempt
        self.identity = identity
        self.privateKey = privateKey
        self.clockMs = clockMs
    }

    internal func sendConnectIfNeeded() async throws {
        if connectSent {
            return
        }
        connectSent = true

        let signedAtMs: Int64 = clockMs()
        let context: OpenClawConnectTextContext = OpenClawConnectTextContext(
            connectId: connectId,
            platform: platform,
            attempt: attempt,
            identity: identity,
            privateKey: privateKey,
            signedAtMs: signedAtMs,
            nonce: connectNonce
        )
        let connectText: String = try OpenClawConnectTextBuilder.makeConnectText(context)
        try await transport.send(text: connectText)
    }

    internal func handleChallenge(nonce: String) async throws {
        connectNonce = nonce
        try await sendConnectIfNeeded()
    }
}
