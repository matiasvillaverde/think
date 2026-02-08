import Abstractions
import CryptoKit
import Foundation
import Testing
@testable import ViewModels

@Suite("OpenClaw Gateway Integration Tests", .tags(.acceptance))
internal struct OpenClawGatewayIntegrationTests {
    @Test("Pairs device and connects to a real OpenClaw gateway (docker harness)")
    func pairsAndConnectsToRealGateway() async throws {
        let url: String? = ProcessInfo.processInfo.environment["OPENCLAW_TEST_WS_URL"]
        guard let url,
              !url.isEmpty else {
            return
        }

        let token: String? = ProcessInfo.processInfo.environment["OPENCLAW_TEST_TOKEN"]

        let instanceId: UUID = UUID()
        let secrets: InMemorySecretsStore = InMemorySecretsStore()
        try await secrets.setSharedToken(instanceId: instanceId, token: token)

        try await OpenClawGatewayIntegrationFlow.run(
            url: url,
            token: token,
            instanceId: instanceId,
            secrets: secrets
        )
    }
}

private enum OpenClawGatewayIntegrationFlow {
    static func run(
        url: String,
        token: String?,
        instanceId: UUID,
        secrets: InMemorySecretsStore
    ) async throws {
        let capture: ConnectCapture = ConnectCapture()
        let client: OpenClawGatewayHandshakeClient = OpenClawGatewayHandshakeClient(secrets: secrets) { wsURL in
            CapturingTransport(
                inner: URLSessionOpenClawWebSocketTransport(url: wsURL, session: .shared),
                capture: capture
            )
        }

        let requestId: String = try await requestPairingId(
            client: client,
            capture: capture,
            instanceId: instanceId,
            url: url,
            token: token
        )
        try await approvePairing(url: url, token: token, requestId: requestId)
        await connectAndAssert(client: client, instanceId: instanceId, url: url)
        try await assertDeviceTokenConnect(secrets: secrets, client: client, instanceId: instanceId, url: url)
    }

    private static func requestPairingId(
        client: OpenClawGatewayHandshakeClient,
        capture: ConnectCapture,
        instanceId: UUID,
        url: String,
        token: String?
    ) async throws -> String {
        let status: OpenClawConnectionStatus = await client.testConnect(
            instanceId: instanceId,
            urlString: url,
            timeoutSeconds: 15
        )

        guard case .pairingRequired(let requestId) = status else {
            if let connectText: String = await capture.lastConnectText() {
                let prefix: String = token.map { String($0.prefix(8)) } ?? "nil"
                print("OpenClaw integration connect payload (token prefix: \(prefix)):\n\(connectText)")
            }
            throw TestFailure("Expected pairingRequired, got: \(status)")
        }
        return requestId
    }

    private static func approvePairing(url: String, token: String?, requestId: String) async throws {
        let rpc: OpenClawGatewayRPCClient = try await OpenClawGatewayRPCClient.connect(
            urlString: url,
            authToken: token,
            includeDevice: false
        )
        defer { Task { await rpc.close() } }

        try await rpc.callOK(method: "device.pair.approve", params: ["requestId": requestId])
    }

    private static func connectAndAssert(
        client: OpenClawGatewayHandshakeClient,
        instanceId: UUID,
        url: String
    ) async {
        let connected: OpenClawConnectionStatus = await client.testConnect(
            instanceId: instanceId,
            urlString: url,
            timeoutSeconds: 15
        )
        #expect(connected == .connected)
    }

    private static func assertDeviceTokenConnect(
        secrets: InMemorySecretsStore,
        client: OpenClawGatewayHandshakeClient,
        instanceId: UUID,
        url: String
    ) async throws {
        let storedDeviceToken: String? = try await secrets.getDeviceToken(
            instanceId: instanceId,
            role: OpenClawDeviceAuth.defaultRole
        )
        #expect(storedDeviceToken != nil)

        try await secrets.setSharedToken(instanceId: instanceId, token: nil)
        let connectedWithDeviceTokenOnly: OpenClawConnectionStatus = await client.testConnect(
            instanceId: instanceId,
            urlString: url,
            timeoutSeconds: 15
        )
        #expect(connectedWithDeviceTokenOnly == .connected)
    }
}

private actor ConnectCapture {
    private var sentTexts: [String] = []

    func recordSentText(_ text: String) {
        sentTexts.append(text)
    }

    func lastConnectText() -> String? {
        sentTexts.last
    }
}

private actor CapturingTransport: OpenClawWebSocketTransporting {
    private let inner: OpenClawWebSocketTransporting
    private let capture: ConnectCapture

    init(inner: OpenClawWebSocketTransporting, capture: ConnectCapture) {
        self.inner = inner
        self.capture = capture
    }

    func start() async {
        await inner.start()
    }

    func close() async {
        await inner.close()
    }

    func send(text: String) async throws {
        await capture.recordSentText(text)
        try await inner.send(text: text)
    }

    func receiveText() async throws -> String {
        try await inner.receiveText()
    }
}

// MARK: - Minimal RPC Client (Test Only)

private actor OpenClawGatewayRPCClient {
    private typealias Proto = OpenClawGatewayProtocol

    private let transport: OpenClawWebSocketTransporting
    private let connectId: String

    private init(transport: OpenClawWebSocketTransporting, connectId: String) {
        self.transport = transport
        self.connectId = connectId
    }

    static func connect(
        urlString: String,
        authToken: String?,
        includeDevice: Bool
    ) async throws -> OpenClawGatewayRPCClient {
        guard let url: URL = OpenClawGatewayURL.normalize(
            urlString,
            securityPolicy: .allowInsecure
        ) else {
            throw TestFailure("Invalid URL")
        }

        let transport: OpenClawWebSocketTransporting = URLSessionOpenClawWebSocketTransport(
            url: url,
            session: .shared
        )
        await transport.start()

        let connectId: String = UUID().uuidString
        let params: Proto.ConnectParams = Proto.ConnectParams(
            minProtocol: Proto.protocolVersion,
            maxProtocol: Proto.protocolVersion,
            client: Proto.ClientInfo(
                id: OpenClawDeviceAuth.defaultClientId,
                displayName: "Think",
                version: "dev",
                platform: "macos",
                mode: OpenClawDeviceAuth.defaultClientMode,
                instanceId: nil
            ),
            auth: authToken.map { Proto.AuthInfo.token($0) },
            role: OpenClawDeviceAuth.defaultRole,
            scopes: OpenClawDeviceAuth.defaultScopes,
            device: includeDevice ? Proto.DeviceInfo(
                id: "invalid",
                publicKey: "invalid",
                signature: "invalid",
                signedAt: 0,
                nonce: nil
            ) : nil
        )
        let frame: Proto.ConnectRequestFrame = Proto.ConnectRequestFrame(id: connectId, params: params)
        let encoder: JSONEncoder = JSONEncoder()
        let connectData: Data = try encoder.encode(frame)
        let connectText: String = String(bytes: connectData, encoding: .utf8) ?? ""

        do {
            try await transport.send(text: connectText)
            try await waitForConnectOK(transport: transport, connectId: connectId)
            return OpenClawGatewayRPCClient(transport: transport, connectId: connectId)
        } catch {
            await transport.close()
            throw error
        }
    }

    func close() async {
        await transport.close()
    }

    func callOK(method: String, params: [String: Any]) async throws {
        let id: String = UUID().uuidString
        let frame: [String: Any] = [
            "type": "req",
            "id": id,
            "method": method,
            "params": params
        ]
        let data: Data = try JSONSerialization.data(withJSONObject: frame, options: [])
        let text: String = String(bytes: data, encoding: .utf8) ?? ""
        try await transport.send(text: text)
        try await waitForResponseOK(transport: transport, id: id)
    }

    private static func waitForConnectOK(
        transport: OpenClawWebSocketTransporting,
        connectId: String
    ) async throws {
        let decoder: JSONDecoder = JSONDecoder()
        while true {
            let raw: String = try await transport.receiveText()
            let data: Data = Data(raw.utf8)

            if let response: Proto.ResponseFrame = try? decoder.decode(Proto.ResponseFrame.self, from: data),
               response.type == "res",
               response.id == connectId {
                if response.isOk {
                    return
                }
                let message: String = response.error?.message ?? "Connection rejected"
                throw TestFailure("Connect failed: \(message)")
            }
        }
    }

    private func waitForResponseOK(
        transport: OpenClawWebSocketTransporting,
        id: String
    ) async throws {
        while true {
            let raw: String = try await transport.receiveText()
            guard let data: Data = raw.data(using: .utf8) else {
                continue
            }

            guard let obj: Any = try? JSONSerialization.jsonObject(with: data),
                  let dict: [String: Any] = obj as? [String: Any],
                  let type: String = dict["type"] as? String else {
                continue
            }

            if type == "event" {
                continue
            }

            guard type == "res",
                  let frameId: String = dict["id"] as? String,
                  frameId == id else {
                continue
            }

            let isOk: Bool = (dict["ok"] as? Bool) ?? false
            if isOk {
                return
            }
            let errorDict: [String: Any] = (dict["error"] as? [String: Any]) ?? [:]
            let message: String = (errorDict["message"] as? String) ?? "unknown error"
            throw TestFailure("Call failed: \(message)")
        }
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

// swiftlint:disable unneeded_throws_rethrows
private actor InMemorySecretsStore: OpenClawSecretsStoring {
    private var sharedTokens: [UUID: String] = [:]
    private var deviceTokens: [String: String] = [:]
    private var identities: [UUID: OpenClawDeviceIdentity] = [:]

    func getSharedToken(instanceId: UUID) async throws -> String? {
        await Task.yield()
        return sharedTokens[instanceId]
    }

    func setSharedToken(instanceId: UUID, token: String?) async throws {
        await Task.yield()
        if let token, !token.isEmpty {
            sharedTokens[instanceId] = token
        } else {
            sharedTokens[instanceId] = nil
        }
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
        sharedTokens[instanceId] = nil
        identities[instanceId] = nil
        deviceTokens = [:]
    }

    func loadOrCreateDeviceIdentity(instanceId: UUID) async throws -> OpenClawDeviceIdentity {
        await Task.yield()
        if let existing = identities[instanceId] {
            return existing
        }
        let privateKey: Curve25519.Signing.PrivateKey = Curve25519.Signing.PrivateKey()
        let identity: OpenClawDeviceIdentity = OpenClawDeviceIdentity(privateKey: privateKey)
        identities[instanceId] = identity
        return identity
    }
}
// swiftlint:enable unneeded_throws_rethrows
