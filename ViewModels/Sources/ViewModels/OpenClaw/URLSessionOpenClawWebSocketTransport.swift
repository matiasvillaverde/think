import Foundation

internal protocol OpenClawWebSocketTransporting: Sendable {
    func start() async
    func send(text: String) async throws
    func receiveText() async throws -> String
    func close() async
}

internal actor URLSessionOpenClawWebSocketTransport: OpenClawWebSocketTransporting {
    private let url: URL
    private let session: URLSession
    private var task: URLSessionWebSocketTask?

    init(url: URL, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }

    deinit { task?.cancel(with: .goingAway, reason: nil) }

    func start() async {
        await Task.yield()
        let newTask: URLSessionWebSocketTask = session.webSocketTask(with: url)
        task = newTask
        newTask.resume()
    }

    func send(text: String) async throws {
        guard let task else {
            throw URLError(.notConnectedToInternet)
        }
        try await task.send(.string(text))
    }

    func receiveText() async throws -> String {
        guard let task else {
            throw URLError(.notConnectedToInternet)
        }

        let msg: URLSessionWebSocketTask.Message = try await task.receive()
        switch msg {
        case .string(let text):
            return text

        case .data(let data):
            return String(bytes: data, encoding: .utf8) ?? ""

        @unknown default:
            throw URLError(.cannotParseResponse)
        }
    }

    func close() async {
        await Task.yield()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }
}
