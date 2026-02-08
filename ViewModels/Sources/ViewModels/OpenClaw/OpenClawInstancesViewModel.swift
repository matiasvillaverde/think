import Abstractions
import Database
import Foundation
import OSLog

public final actor OpenClawInstancesViewModel: OpenClawInstancesViewModeling {
    private let logger: Logger = Logger(
        subsystem: "ViewModels",
        category: String(describing: OpenClawInstancesViewModel.self)
    )

    private let database: DatabaseProtocol
    private let handshakeClient: OpenClawGatewayHandshakeClient
    private let secrets: OpenClawSecretsStoring

    private var internalInstances: [OpenClawInstanceRecord] = []
    private var internalStatuses: [UUID: OpenClawConnectionStatus] = [:]

    public var instances: [OpenClawInstanceRecord] { internalInstances }
    public var connectionStatuses: [UUID: OpenClawConnectionStatus] { internalStatuses }

    public init(database: DatabaseProtocol) {
        self.database = database
        self.secrets = OpenClawKeychainSecretsStore()
        self.handshakeClient = OpenClawGatewayHandshakeClient(secrets: secrets)
    }

    init(
        database: DatabaseProtocol,
        handshakeClient: OpenClawGatewayHandshakeClient,
        secrets: OpenClawSecretsStoring
    ) {
        self.database = database
        self.handshakeClient = handshakeClient
        self.secrets = secrets
    }

    public func refresh() async {
        do {
            let records: [OpenClawInstanceRecord] = try await database.read(
                SettingsCommands.FetchOpenClawInstances()
            )

            // Decorate records with keychain-backed auth presence.
            var decorated: [OpenClawInstanceRecord] = []
            decorated.reserveCapacity(records.count)
            for record in records {
                let sharedToken: String? = try await secrets.getSharedToken(instanceId: record.id)
                let deviceToken: String? = try await secrets.getDeviceToken(
                    instanceId: record.id,
                    role: OpenClawDeviceAuth.defaultRole
                )
                let hasAuth: Bool = !((deviceToken ?? sharedToken) ?? "").isEmpty
                decorated.append(
                    OpenClawInstanceRecord(
                        id: record.id,
                        name: record.name,
                        urlString: record.urlString,
                        hasAuthToken: hasAuth,
                        isActive: record.isActive,
                        createdAt: record.createdAt,
                        updatedAt: record.updatedAt
                    )
                )
            }
            internalInstances = decorated

            // Keep existing statuses, but prune removed IDs.
            let ids: Set<UUID> = Set(records.map(\.id))
            internalStatuses = internalStatuses.filter { ids.contains($0.key) }
        } catch {
            logger.error("Failed to refresh OpenClaw instances: \(error.localizedDescription)")
        }
    }

    public func upsertInstance(
        id: UUID?,
        name: String,
        urlString: String,
        authToken: String?
    ) async throws {
        let trimmedName: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL: String = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            throw DatabaseError.invalidInput("Name is required")
        }
        if trimmedURL.isEmpty {
            throw DatabaseError.invalidInput("URL is required")
        }

        // Persist token securely in Keychain. The database only stores non-secret metadata.
        let instanceId: UUID = try await database.write(
            SettingsCommands.UpsertOpenClawInstance(
                id: id,
                name: trimmedName,
                urlString: trimmedURL,
                authToken: nil
            )
        )
        try await secrets.setSharedToken(instanceId: instanceId, token: authToken)
        await refresh()
    }

    public func deleteInstance(id: UUID) async throws {
        _ = try await database.write(SettingsCommands.DeleteOpenClawInstance(id: id))
        try await secrets.deleteSecrets(instanceId: id)
        internalStatuses[id] = nil
        await refresh()
    }

    public func setActiveInstance(id: UUID?) async throws {
        _ = try await database.write(SettingsCommands.SetActiveOpenClawInstance(id: id))
        await refresh()
    }

    public func testConnection(id: UUID) async {
        internalStatuses[id] = .connecting

        do {
            let config: OpenClawInstanceConfiguration = try await database.read(
                SettingsCommands.GetOpenClawInstanceConfiguration(id: id)
            )
            let result: OpenClawConnectionStatus = await handshakeClient.testConnect(
                instanceId: id,
                urlString: config.urlString
            )
            internalStatuses[id] = result
        } catch {
            internalStatuses[id] = .failed(message: error.localizedDescription)
        }
    }
}
