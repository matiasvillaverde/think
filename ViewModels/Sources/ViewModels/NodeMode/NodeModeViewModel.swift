import Abstractions
import Database
import Foundation
import OSLog

public actor NodeModeViewModel: NodeModeViewModeling {
    private let database: DatabaseProtocol
    private let server: NodeModeServer
    private let logger: Logger = Logger(subsystem: "ViewModels", category: "NodeModeViewModel")

    private var cachedSettings: AppSettings?
    private var running: Bool = false

    public init(
        database: DatabaseProtocol,
        gateway: GatewayServicing
    ) {
        self.database = database
        self.server = NodeModeServer(gateway: gateway)

        Task { [weak self] in
            await self?.refresh()
        }
    }

    public var isEnabled: Bool { cachedSettings?.nodeModeEnabled ?? false }
    public var isRunning: Bool { running }
    public var port: Int { cachedSettings?.nodeModePort ?? 9876 }
    public var authToken: String? { cachedSettings?.nodeModeAuthToken }

    public func refresh() async {
        do {
            let settings = try await database.read(SettingsCommands.GetOrCreate())
            cachedSettings = settings
            await apply(settings)
        } catch {
            logger.error("Failed to refresh node settings: \(error.localizedDescription)")
        }
    }

    public func setEnabled(_ enabled: Bool) async {
        _ = try? await database.write(SettingsCommands.UpdateNode(nodeModeEnabled: .set(enabled)))
        await refresh()
    }

    public func updatePort(_ port: Int) async {
        let sanitized = max(1, min(port, Int(UInt16.max)))
        _ = try? await database.write(SettingsCommands.UpdateNode(nodeModePort: .set(sanitized)))
        await refresh()
    }

    public func updateAuthToken(_ token: String?) async {
        _ = try? await database.write(SettingsCommands.UpdateNode(nodeModeAuthToken: .set(token)))
        await refresh()
    }

    private func apply(_ settings: AppSettings) async {
        if settings.nodeModeEnabled {
            let portValue = UInt16(clamping: settings.nodeModePort)
            do {
                try await server.start(
                    configuration: NodeModeConfiguration(
                        port: portValue,
                        authToken: settings.nodeModeAuthToken
                    )
                )
                running = true
            } catch {
                logger.error("Failed to start node server: \(error.localizedDescription)")
                running = false
            }
        } else {
            await server.stop()
            running = false
        }
    }
}
