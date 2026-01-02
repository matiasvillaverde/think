import Abstractions
import Foundation
import Network
import OSLog

/// Configuration values for the node mode server.
public struct NodeModeConfiguration: Sendable, Equatable {
    /// Port used for the local server.
    public let port: UInt16
    /// Optional bearer token for authorization.
    public let authToken: String?

    /// Creates a configuration for the node mode server.
    /// - Parameters:
    ///   - port: Port used to bind the server.
    ///   - authToken: Optional bearer token.
    public init(port: UInt16, authToken: String?) {
        self.port = port
        self.authToken = authToken
    }
}

/// Hosts a local HTTP server for node mode requests.
public actor NodeModeServer {
    private let logger: Logger = Logger(subsystem: "ViewModels", category: "NodeModeServer")
    private let handler: NodeModeRequestHandler
    private let queue: DispatchQueue = DispatchQueue(label: "node.mode.server")
    private var listener: NWListener?
    private var configuration: NodeModeConfiguration?

    /// Indicates whether the server is currently running.
    public var isRunning: Bool {
        listener != nil
    }

    /// Creates a node mode server.
    /// - Parameter gateway: Gateway service used to execute requests.
    public init(gateway: GatewayServicing) {
        self.handler = NodeModeRequestHandler(gateway: gateway)
    }

    /// Starts listening for node mode requests.
    /// - Parameter configuration: Server configuration.
    public func start(configuration: NodeModeConfiguration) async throws {
        if let listener {
            listener.cancel()
            self.listener = nil
        }

        let params: NWParameters = NWParameters.tcp
        guard let port: NWEndpoint.Port = NWEndpoint.Port(rawValue: configuration.port) else {
            throw NodeModeServerError.invalidPort
        }
        let listener: NWListener = try NWListener(using: params, on: port)
        self.configuration = configuration

        try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    listener.stateUpdateHandler = nil
                    continuation.resume()

                case .failed(let error):
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: error)

                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                Task { [weak self] in
                    guard let self else {
                        return
                    }
                    await handleConnection(connection)
                }
            }

            listener.start(queue: queue)
        }

        self.listener = listener
        logger.notice("Node mode server started on port \(configuration.port)")
    }

    /// Stops the server if it is running.
    public func stop() {
        listener?.cancel()
        listener = nil
        configuration = nil
        logger.notice("Node mode server stopped")
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        let context: ConnectionContext = ConnectionContext(connection: connection)
        receiveNext(on: context)
    }

    nonisolated private func receiveNext(on context: ConnectionContext) {
        context.connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 65_536
        ) { [weak self] data, _, isComplete, error in
            guard let self else {
                return
            }
            if let data {
                context.buffer.append(data)
                while let request: HTTPRequest = HTTPParser.parse(from: &context.buffer) {
                    Task { [weak self] in
                        guard let self else {
                            return
                        }
                        await respond(to: request, on: context.connection)
                    }
                }
            }

            if isComplete || error != nil {
                context.connection.cancel()
                return
            }

            receiveNext(on: context)
        }
    }

    private func respond(to request: HTTPRequest, on connection: NWConnection) async {
        let config: NodeModeConfiguration = configuration ?? NodeModeConfiguration(
            port: 0,
            authToken: nil
        )
        let response: HTTPResponse = await handler.handle(request: request, configuration: config)
        let data: Data = response.serialized()

        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

private enum NodeModeServerError: Error {
    case invalidPort
}

// MARK: - Connection Context

private final class ConnectionContext: @unchecked Sendable {
    let connection: NWConnection
    var buffer: Data = Data()

    init(connection: NWConnection) {
        self.connection = connection
    }

    deinit {
        // No-op
    }
}
