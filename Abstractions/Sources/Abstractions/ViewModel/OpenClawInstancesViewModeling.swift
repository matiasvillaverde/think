import Foundation

/// Protocol defining OpenClaw remote instance management.
public protocol OpenClawInstancesViewModeling: Actor {
    var instances: [OpenClawInstanceRecord] { get async }
    var connectionStatuses: [UUID: OpenClawConnectionStatus] { get async }

    func refresh() async
    func upsertInstance(
        id: UUID?,
        name: String,
        urlString: String,
        authToken: String?
    ) async throws
    func deleteInstance(id: UUID) async throws
    func setActiveInstance(id: UUID?) async throws
    func testConnection(id: UUID) async
}
