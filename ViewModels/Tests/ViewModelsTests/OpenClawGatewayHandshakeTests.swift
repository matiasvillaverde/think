import Abstractions
import CryptoKit
import Foundation
import Testing
@testable import ViewModels

@Suite("OpenClaw Gateway Handshake Tests")
internal struct OpenClawGatewayHandshakeTests {
    // swiftlint:disable function_body_length
    @Test("Handshake consumes connect.challenge, signs v2 payload, and stores deviceToken")
    func handshakeSignsChallengeAndStoresDeviceToken() async throws {
        let instanceId: UUID = UUID()
        let sharedToken: String = "shared"
        let role: String = OpenClawDeviceAuth.defaultRole

        let rawPrivate: Data = Data((0..<32).map { UInt8($0 ^ 0x5a) })
        let privateKey: Curve25519.Signing.PrivateKey =
            try Curve25519.Signing.PrivateKey(rawRepresentation: rawPrivate)
        let identity: OpenClawDeviceIdentity = OpenClawDeviceIdentity(privateKey: privateKey)

        let secrets: InMemorySecretsStore = InMemorySecretsStore(
            sharedToken: sharedToken,
            identity: identity
        )

        let transport: MockTransport = MockTransport(
            initialIncoming: [
                """
                {"type":"event","event":"connect.challenge","payload":{"nonce":"abc","ts":123}}
                """
            ]
        )

        let clockMs: Int64 = 1_700_000_000_123
        let client: OpenClawGatewayHandshakeClient = OpenClawGatewayHandshakeClient(
            secrets: secrets,
            clockMs: { clockMs },
            transportFactory: { _ in transport }
        )

        let status: OpenClawConnectionStatus = await client.testConnect(
            instanceId: instanceId,
            urlString: "ws://example.invalid",
            timeoutSeconds: 2
        )
        #expect(status == .connected)

        let sent: [String] = await transport.sentTexts
        #expect(sent.count == 1)

        let connectJSON: String = sent[0]
        let decoder: JSONDecoder = JSONDecoder()
        let frame: OpenClawGatewayProtocol.ConnectRequestFrame = try decoder.decode(
            OpenClawGatewayProtocol.ConnectRequestFrame.self,
            from: Data(connectJSON.utf8)
        )
        #expect(frame.type == "req")
        #expect(frame.method == "connect")
        #expect(frame.params.role == role)
        #expect(frame.params.scopes == OpenClawDeviceAuth.defaultScopes)

        let device: OpenClawGatewayProtocol.DeviceInfo? = frame.params.device
        #expect(device?.id == identity.deviceId)
        #expect(device?.publicKey == identity.publicKeyRawBase64Url)
        #expect(device?.nonce == "abc")
        #expect(device?.signedAt == clockMs)

        guard let signature: String = device?.signature else {
            throw TestFailure("Missing device.signature")
        }

        let tokenFromFrame: String? = {
            guard let auth: OpenClawGatewayProtocol.AuthInfo = frame.params.auth else {
                return nil
            }
            switch auth {
            case .token(let token):
                return token
            }
        }()
        #expect(tokenFromFrame == sharedToken)

        let payloadParams: OpenClawDeviceAuth.PayloadParams = OpenClawDeviceAuth.PayloadParams(
            deviceId: identity.deviceId,
            clientId: OpenClawDeviceAuth.defaultClientId,
            clientMode: OpenClawDeviceAuth.defaultClientMode,
            role: frame.params.role,
            scopes: frame.params.scopes,
            signedAtMs: device?.signedAt ?? clockMs,
            token: tokenFromFrame,
            nonce: device?.nonce
        )
        let expectedPayload: String = OpenClawDeviceAuth.buildPayload(payloadParams)

        guard let signatureRaw: Data = OpenClawBase64URL.decode(signature) else {
            throw TestFailure("device.signature is not valid base64url")
        }
        let payloadData: Data = Data(expectedPayload.utf8)
        let publicKeyRaw: Data = privateKey.publicKey.rawRepresentation
        let publicKey: Curve25519.Signing.PublicKey = try Curve25519.Signing.PublicKey(
            rawRepresentation: publicKeyRaw
        )
        #expect(publicKey.isValidSignature(signatureRaw, for: payloadData))

        let storedDeviceToken: String? = try await secrets.getDeviceToken(instanceId: instanceId, role: role)
        #expect(storedDeviceToken == "device-token-123")
    }
}

// swiftlint:enable function_body_length

// MARK: - Test Doubles

// swiftlint:disable unneeded_throws_rethrows
private actor InMemorySecretsStore: OpenClawSecretsStoring {
    private let sharedTokenValue: String?
    private let identityValue: OpenClawDeviceIdentity
    private var deviceTokens: [String: String] = [:]

    init(sharedToken: String?, identity: OpenClawDeviceIdentity) {
        self.sharedTokenValue = sharedToken
        self.identityValue = identity
    }

    func getSharedToken(instanceId: UUID) async throws -> String? {
        await Task.yield()
        _ = instanceId
        return sharedTokenValue
    }

    func setSharedToken(instanceId: UUID, token: String?) async throws {
        await Task.yield()
        _ = instanceId
        _ = token
    }

    func getDeviceToken(instanceId: UUID, role: String) async throws -> String? {
        await Task.yield()
        _ = instanceId
        return deviceTokens[role]
    }

    func setDeviceToken(instanceId: UUID, role: String, token: String?) async throws {
        await Task.yield()
        _ = instanceId
        deviceTokens[role] = token
    }

    func deleteSecrets(instanceId: UUID) async throws {
        await Task.yield()
        _ = instanceId
        deviceTokens = [:]
    }

    func loadOrCreateDeviceIdentity(instanceId: UUID) async throws -> OpenClawDeviceIdentity {
        await Task.yield()
        _ = instanceId
        return identityValue
    }
}
// swiftlint:enable unneeded_throws_rethrows

private actor MockTransport: OpenClawWebSocketTransporting {
    private var queue: [String]
    private var waiter: CheckedContinuation<String, Error>?
    private(set) var sentTexts: [String] = []

    init(initialIncoming: [String]) {
        self.queue = initialIncoming
    }

    func start() async {
        await Task.yield()
    }

    func send(text: String) async throws {
        await Task.yield()
        try Task.checkCancellation()
        sentTexts.append(text)

        // When we see connect request, respond with hello-ok and deviceToken.
        let decoder: JSONDecoder = JSONDecoder()
        guard let frame: OpenClawGatewayProtocol.ConnectRequestFrame = try? decoder.decode(
            OpenClawGatewayProtocol.ConnectRequestFrame.self,
            from: Data(text.utf8)
        ) else {
            return
        }

        let response: String =
            "{\"type\":\"res\",\"id\":\"\(frame.id)\",\"ok\":true,\"payload\":{\"type\":\"hello-ok\",\"protocol\":3,"
            + "\"auth\":{\"deviceToken\":\"device-token-123\",\"role\":\"operator\",\"scopes\":[\"operator.admin\"]}}}"
        if let waiter {
            self.waiter = nil
            waiter.resume(returning: response)
        } else {
            queue.append(response)
        }
    }

    func receiveText() async throws -> String {
        try Task.checkCancellation()
        if !queue.isEmpty {
            return queue.removeFirst()
        }
        return try await withCheckedThrowingContinuation { cont in
            waiter = cont
        }
    }

    func close() async {
        await Task.yield()
        if let waiter {
            self.waiter = nil
            waiter.resume(throwing: CancellationError())
        }
    }
}

private struct TestFailure: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}
