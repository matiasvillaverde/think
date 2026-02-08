import Abstractions
import CryptoKit
import Foundation

/// OpenClaw Gateway WebSocket handshake (protocol v3).
///
/// Mirrors upstream OpenClaw behavior:
/// - Wait briefly for `connect.challenge` (nonce). If present, sign v2 payload (includes nonce).
/// - Otherwise, send connect after a short delay with v1 payload.
/// - Store any returned `deviceToken` for future connects.
internal struct OpenClawGatewayHandshakeClient: Sendable {
    private typealias Proto = OpenClawGatewayProtocol
    private typealias HandshakeError = OpenClawGatewayProtocol.HandshakeError

    private let transportFactory: @Sendable (URL) -> OpenClawWebSocketTransporting
    private let secrets: OpenClawSecretsStoring
    private let clockMs: @Sendable () -> Int64

    init(
        secrets: OpenClawSecretsStoring = OpenClawKeychainSecretsStore(),
        clockMs: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1_000) },
        transportFactory: @escaping @Sendable (URL) -> OpenClawWebSocketTransporting = { url in
            URLSessionOpenClawWebSocketTransport(url: url)
        }
    ) {
        self.secrets = secrets
        self.clockMs = clockMs
        self.transportFactory = transportFactory
    }

    /// Convenience initializer for the common case where callers only need to inject the transport.
    /// This avoids multiple-closure call sites (SwiftLint `multiple_closures_with_trailing_closure`).
    init(
        secrets: OpenClawSecretsStoring = OpenClawKeychainSecretsStore(),
        transportFactory: @escaping @Sendable (URL) -> OpenClawWebSocketTransporting
    ) {
        self.init(
            secrets: secrets,
            clockMs: { Int64(Date().timeIntervalSince1970 * 1_000) },
            transportFactory: transportFactory
        )
    }

    func testConnect(
        instanceId: UUID,
        urlString: String,
        timeoutSeconds: TimeInterval = 7
    ) async -> OpenClawConnectionStatus {
        guard let url: URL = Self.normalizeWebSocketURL(urlString) else {
            return .failed(message: "Invalid URL")
        }

        let role: String = OpenClawDeviceAuth.defaultRole
        let scopes: [String] = OpenClawDeviceAuth.defaultScopes

        do {
            let sharedToken: String? = try await secrets.getSharedToken(instanceId: instanceId)
            let deviceToken: String? = try await secrets.getDeviceToken(instanceId: instanceId, role: role)
            let canFallbackToShared: Bool = (deviceToken != nil) && (sharedToken != nil)

            do {
                let attempt: OpenClawConnectAttempt = OpenClawConnectAttempt(
                    instanceId: instanceId,
                    url: url,
                    role: role,
                    scopes: scopes,
                    authToken: deviceToken ?? sharedToken,
                    timeoutSeconds: timeoutSeconds
                )
                try await connectOnce(attempt)
                return .connected
            } catch {
                if canFallbackToShared {
                    try await secrets.setDeviceToken(instanceId: instanceId, role: role, token: nil)
                    let attempt: OpenClawConnectAttempt = OpenClawConnectAttempt(
                        instanceId: instanceId,
                        url: url,
                        role: role,
                        scopes: scopes,
                        authToken: sharedToken,
                        timeoutSeconds: timeoutSeconds
                    )
                    try await connectOnce(attempt)
                    return .connected
                }
                throw error
            }
        } catch let error as HandshakeError {
            switch error {
            case .timeout:
                return .failed(message: "Timed out")

            case .pairingRequired(let requestId):
                return .pairingRequired(requestId: requestId)

            case .serverRejected(let message):
                return .failed(message: message)

            case .invalidResponse:
                return .failed(message: "Invalid response")
            }
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    // MARK: - Implementation

    // swiftlint:disable function_body_length
    private func connectOnce(_ attempt: OpenClawConnectAttempt) async throws {
        let transport: OpenClawWebSocketTransporting = transportFactory(attempt.url)
        await transport.start()
        defer { Task { await transport.close() } }

        let connectId: String = UUID().uuidString
        let platform: String = Self.platformValue()
        let identity: OpenClawDeviceIdentity = try await secrets.loadOrCreateDeviceIdentity(
            instanceId: attempt.instanceId
        )
        let privateKey: Curve25519.Signing.PrivateKey = try Curve25519.Signing.PrivateKey(
            rawRepresentation: identity.privateKeyRaw
        )

        let coordinator: OpenClawConnectCoordinator = OpenClawConnectCoordinator(
            transport: transport,
            connectId: connectId,
            platform: platform,
            attempt: attempt,
            identity: identity,
            privateKey: privateKey,
            clockMs: clockMs
        )

        let delayedConnectTask: Task<Void, Error> = Task {
            try await Task.sleep(nanoseconds: 750_000_000)
            try await coordinator.sendConnectIfNeeded()
        }
        defer { delayedConnectTask.cancel() }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await receiveUntilHelloOk(
                    transport: transport,
                    connectId: connectId,
                    attempt: attempt
                ) { nonce in
                    try await coordinator.handleChallenge(nonce: nonce)
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(attempt.timeoutSeconds * 1_000_000_000))
                throw HandshakeError.timeout
            }

            if try await group.next() == nil {
                throw HandshakeError.invalidResponse
            }
            group.cancelAll()
        }
    }
    // swiftlint:enable function_body_length

    // Coordination/types + connect frame builder live in `OpenClawGatewayHandshakeInternals.swift`.

    private func receiveUntilHelloOk(
        transport: OpenClawWebSocketTransporting,
        connectId: String,
        attempt: OpenClawConnectAttempt,
        onChallenge: @Sendable (String) async throws -> Void
    ) async throws {
        let decoder: JSONDecoder = JSONDecoder()

        while true {
            let raw: String = try await transport.receiveText()
            let data: Data = Data(raw.utf8)

            if data.isEmpty {
                continue
            }

            if let event: Proto.EventFrame = try? decoder.decode(Proto.EventFrame.self, from: data),
               event.type == "event",
               event.event == "connect.challenge",
               let nonce = event.payload?.nonce,
               !nonce.isEmpty {
                try await onChallenge(nonce)
                continue
            }

            guard let response: Proto.ResponseFrame = try? decoder.decode(Proto.ResponseFrame.self, from: data),
                  response.type == "res",
                  response.id == connectId else {
                continue
            }

            if !response.isOk {
                let message: String = response.error?.message ?? "Connection rejected"
                if response.error?.code == "NOT_PAIRED",
                   let requestId: String = response.error?.details?.requestId,
                   !requestId.isEmpty {
                    throw HandshakeError.pairingRequired(requestId: requestId)
                }
                throw HandshakeError.serverRejected(message: message)
            }

            guard let payload: Proto.HelloOkPayload = response.payload else {
                throw HandshakeError.invalidResponse
            }

            if let deviceToken: String = payload.auth?.deviceToken {
                let tokenRole: String = payload.auth?.role ?? attempt.role
                try await secrets.setDeviceToken(
                    instanceId: attempt.instanceId,
                    role: tokenRole,
                    token: deviceToken
                )
            }

            return
        }
    }

    private static func normalizeWebSocketURL(_ raw: String) -> URL? {
        let trimmed: String = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }

        if let url: URL = URL(string: trimmed),
           let scheme: String = url.scheme?.lowercased() {
            if scheme == "ws" || scheme == "wss" {
                return url
            }
            if scheme == "http" || scheme == "https" {
                var components: URLComponents? = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.scheme = (scheme == "https") ? "wss" : "ws"
                return components?.url
            }
        }

        return URL(string: "wss://\(trimmed)")
    }

    private static func platformValue() -> String {
#if os(iOS)
        return "ios"
#elseif os(visionOS)
        return "visionos"
#else
        return "macos"
#endif
    }
}
