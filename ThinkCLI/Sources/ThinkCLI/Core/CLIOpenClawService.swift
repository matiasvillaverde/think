import Abstractions
import ArgumentParser
import Database
import Foundation
import RemoteSession
import ViewModels

// Keep these in-sync with OpenClaw gateway client defaults.
private enum OpenClawCLIAuthDefaults {
    static let role: String = "operator"
    static let scopes: [String] = ["operator.admin"]
    static let clientId: String = "gateway-client"
    static let clientMode: String = "backend"
}

enum CLIOpenClawService {
    static func list(runtime: CLIRuntime) async throws {
        let instances: [OpenClawInstanceRecord] = try await runtime.database.read(
            SettingsCommands.FetchOpenClawInstances()
        )

        let storage: SecureStorageProtocol = await OpenClawSecureStorageProvider.storage()
        let tokens: [UUID: Bool] = await loadTokenPresence(storage: storage, instances: instances)

        if instances.isEmpty {
            runtime.output.emit("No OpenClaw instances configured.")
            return
        }

        for instance in instances {
            let activeMark: String = instance.isActive ? "*" : " "
            let hasToken: Bool = tokens[instance.id] ?? false
            let tokenText: String = hasToken ? "yes" : "no"
            runtime.output.emit("\(activeMark) \(instance.id.uuidString)  \(instance.name)")
            runtime.output.emit("  \(instance.urlString)  token=\(tokenText)")
        }
    }

    static func upsert(
        runtime: CLIRuntime,
        id: UUID?,
        name: String,
        urlString: String,
        token: String?,
        activate: Bool
    ) async throws {
        let trimmedName: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL: String = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            throw ValidationError("Name is required.")
        }
        if trimmedURL.isEmpty {
            throw ValidationError("URL is required.")
        }

        // Never store auth tokens in SwiftData; they live in Keychain.
        let instanceId: UUID = try await runtime.database.write(
            SettingsCommands.UpsertOpenClawInstance(
                id: id,
                name: trimmedName,
                urlString: trimmedURL,
                authToken: nil
            )
        )

        if let token {
            let storage: SecureStorageProtocol = await OpenClawSecureStorageProvider.storage()
            let secrets: OpenClawCLISecrets = OpenClawCLISecrets(storage: storage)
            try await secrets.setSharedToken(instanceId: instanceId, token: token)
        }

        if activate {
            _ = try await runtime.database.write(
                SettingsCommands.SetActiveOpenClawInstance(id: instanceId)
            )
        }

        runtime.output.emit("OpenClaw instance saved: \(instanceId.uuidString)")
    }

    static func delete(runtime: CLIRuntime, id: UUID) async throws {
        _ = try await runtime.database.write(SettingsCommands.DeleteOpenClawInstance(id: id))

        let storage: SecureStorageProtocol = await OpenClawSecureStorageProvider.storage()
        let secrets: OpenClawCLISecrets = OpenClawCLISecrets(storage: storage)
        try await secrets.deleteSecrets(instanceId: id)

        runtime.output.emit("OpenClaw instance deleted: \(id.uuidString)")
    }

    static func use(runtime: CLIRuntime, id: UUID?) async throws {
        _ = try await runtime.database.write(SettingsCommands.SetActiveOpenClawInstance(id: id))
        runtime.output.emit("Active OpenClaw instance set to: \(id?.uuidString ?? "none")")
    }

    static func test(runtime: CLIRuntime, id: UUID) async throws {
        // Use the shared implementation from ViewModels so CLI matches app behavior.
        let viewModel = OpenClawInstancesViewModel(database: runtime.database)
        await viewModel.refresh()
        await viewModel.testConnection(id: id)
        let statuses: [UUID: OpenClawConnectionStatus] = await viewModel.connectionStatuses
        let status: OpenClawConnectionStatus = statuses[id] ?? .idle

        switch status {
        case .connected:
            runtime.output.emit("Connected.")

        case .pairingRequired(let requestId):
            runtime.output.emit("Pairing required. requestId=\(requestId)")
            runtime.output.emit("Approve from the gateway, then re-run:")
            runtime.output.emit("  think openclaw test --id \(id.uuidString)")

        case .connecting:
            runtime.output.emit("Connecting…")

        case .failed(let message):
            runtime.output.emit("Failed: \(message)")

        case .idle:
            runtime.output.emit("Not tested.")
        }
    }

    static func approvePairing(urlString: String, token: String, requestId: String) async throws {
        let url: URL = try normalizeWebSocketURL(urlString)
        let rpc: OpenClawGatewayRPC = OpenClawGatewayRPC(url: url, token: token)
        try await rpc.connect()
        defer { Task { await rpc.close() } }
        try await rpc.callOK(method: "device.pair.approve", params: ["requestId": requestId])
    }
}


// MARK: - Secure Storage (Keychain)

private struct OpenClawCLISecrets: Sendable {
    private let storage: SecureStorageProtocol

    init(storage: SecureStorageProtocol) {
        self.storage = storage
    }

    func setSharedToken(instanceId: UUID, token: String) async throws {
        let trimmed: String = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try await storage.delete(forKey: keySharedToken(instanceId))
            return
        }
        guard let data: Data = trimmed.data(using: .utf8) else {
            return
        }
        try await storage.store(data, forKey: keySharedToken(instanceId))
    }

    func deleteSecrets(instanceId: UUID) async throws {
        try await storage.delete(forKey: keySharedToken(instanceId))
        try await storage.delete(forKey: keyDevicePrivateKey(instanceId))
        try await storage.delete(
            forKey: keyDeviceToken(instanceId, role: OpenClawCLIAuthDefaults.role)
        )
    }

    private func keySharedToken(_ id: UUID) -> String {
        "openclaw.instance.\(id.uuidString).shared_token"
    }

    private func keyDeviceToken(_ id: UUID, role: String) -> String {
        let normalizedRole: String = role.trimmingCharacters(in: .whitespacesAndNewlines)
        return "openclaw.instance.\(id.uuidString).device_token.\(normalizedRole)"
    }

    private func keyDevicePrivateKey(_ id: UUID) -> String {
        "openclaw.instance.\(id.uuidString).device_private_key"
    }
}

private func loadTokenPresence(
    storage: SecureStorageProtocol,
    instances: [OpenClawInstanceRecord]
) async -> [UUID: Bool] {
    await withTaskGroup(of: (UUID, Bool).self) { group in
        for instance in instances {
            group.addTask {
                let key: String = "openclaw.instance.\(instance.id.uuidString).shared_token"
                let exists: Bool = await storage.exists(forKey: key)
                return (instance.id, exists)
            }
        }

        var out: [UUID: Bool] = [:]
        for await (id, exists) in group {
            out[id] = exists
        }
        return out
    }
}

private func normalizeWebSocketURL(_ raw: String) throws -> URL {
    do {
        return try OpenClawGatewayURL.normalizeOrThrow(raw)
    } catch OpenClawGatewayURL.NormalizationError.invalidInput {
        throw ValidationError("Invalid URL: \(raw)")
    } catch OpenClawGatewayURL.NormalizationError.insecureTransportNotAllowed {
        throw ValidationError("Insecure transport (ws://) is not allowed. Use wss:// instead.")
    } catch {
        throw ValidationError("Invalid URL: \(raw)")
    }
}

// MARK: - Minimal Gateway RPC

private actor OpenClawGatewayRPC {
    private let url: URL
    private let token: String

    private var task: URLSessionWebSocketTask?
    private var connectId: String?

    init(url: URL, token: String) {
        self.url = url
        self.token = token
    }

    func connect() async throws {
        let session: URLSession = .shared
        let task: URLSessionWebSocketTask = session.webSocketTask(with: url)
        self.task = task
        task.resume()

        let connectId: String = UUID().uuidString
        self.connectId = connectId

        let connectFrame: [String: Any] = [
            "type": "req",
            "id": connectId,
            "method": "connect",
            "params": [
                "minProtocol": 3,
                "maxProtocol": 3,
                "caps": [],
                "client": [
                    "id": OpenClawCLIAuthDefaults.clientId,
                    "displayName": "ThinkCLI",
                    "version": "dev",
                    "platform": "macos",
                    "mode": OpenClawCLIAuthDefaults.clientMode
                ],
                "auth": ["token": token],
                "role": OpenClawCLIAuthDefaults.role,
                "scopes": OpenClawCLIAuthDefaults.scopes
            ]
        ]
        let data: Data = try JSONSerialization.data(withJSONObject: connectFrame, options: [])
        let text: String = String(bytes: data, encoding: .utf8) ?? ""
        try await task.send(.string(text))

        try await waitForConnectOK(connectId: connectId)
    }

    func callOK(method: String, params: [String: Any]) async throws {
        guard let task else {
            throw CLIError(message: "Gateway RPC not connected", exitCode: .unavailable)
        }
        let id: String = UUID().uuidString
        let frame: [String: Any] = [
            "type": "req",
            "id": id,
            "method": method,
            "params": params
        ]
        let data: Data = try JSONSerialization.data(withJSONObject: frame, options: [])
        let text: String = String(bytes: data, encoding: .utf8) ?? ""
        try await task.send(.string(text))
        try await waitForResponseOK(id: id)
    }

    func close() async {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    // MARK: - Wait Helpers

    private func waitForConnectOK(connectId: String) async throws {
        while true {
            let dict: [String: Any] = try await receiveJSON()
            guard dict["type"] as? String == "res",
                  dict["id"] as? String == connectId else {
                continue
            }

            let ok: Bool = dict["ok"] as? Bool ?? false
            if ok {
                return
            }
            let errorDict: [String: Any] = dict["error"] as? [String: Any] ?? [:]
            let message: String = errorDict["message"] as? String ?? "connect failed"
            throw CLIError(message: "Gateway connect failed: \(message)", exitCode: .permission)
        }
    }

    private func waitForResponseOK(id: String) async throws {
        while true {
            let dict: [String: Any] = try await receiveJSON()
            guard dict["type"] as? String == "res",
                  dict["id"] as? String == id else {
                continue
            }

            let ok: Bool = dict["ok"] as? Bool ?? false
            if ok {
                return
            }
            let errorDict: [String: Any] = dict["error"] as? [String: Any] ?? [:]
            let message: String = errorDict["message"] as? String ?? "request failed"
            throw CLIError(message: "Gateway call failed: \(message)", exitCode: .unavailable)
        }
    }

    private func receiveJSON() async throws -> [String: Any] {
        guard let task else {
            throw CLIError(message: "Gateway RPC not connected", exitCode: .unavailable)
        }

        while true {
            let message: URLSessionWebSocketTask.Message = try await task.receive()
            let text: String
            switch message {
            case .string(let value):
                text = value
            case .data(let data):
                text = String(bytes: data, encoding: .utf8) ?? ""
            @unknown default:
                continue
            }

            guard let data: Data = text.data(using: .utf8),
                  let obj: Any = try? JSONSerialization.jsonObject(with: data),
                  let dict: [String: Any] = obj as? [String: Any] else {
                continue
            }

            // Ignore events.
            if dict["type"] as? String == "event" {
                continue
            }

            return dict
        }
    }
}
