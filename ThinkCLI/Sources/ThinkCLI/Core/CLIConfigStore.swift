import Foundation

struct CLIConfigStore {
    static let overrideEnvKey: String = "THINK_CLI_CONFIG"

    let url: URL
    let fileManager: FileManager
    let encoder: JSONEncoder
    let decoder: JSONDecoder

    init(
        url: URL = CLIConfigStore.defaultURL(),
        fileManager: FileManager = .default,
        encoder: JSONEncoder = CLIConfigStore.makeEncoder(),
        decoder: JSONDecoder = CLIConfigStore.makeDecoder()
    ) {
        self.url = url
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
    }

    static func defaultURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL {
        if let override = environment[overrideEnvKey], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }

        let base = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser

        return base
            .appendingPathComponent("ThinkCLI", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    func load() throws -> CLIConfig {
        guard fileManager.fileExists(atPath: url.path) else {
            return CLIConfig()
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(CLIConfig.self, from: data)
    }


    func loadOrDefault() -> CLIConfig {
        (try? load()) ?? CLIConfig()
    }

    func save(_ config: CLIConfig) throws {
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(config)
        try data.write(to: url, options: [.atomic])
    }

    func reset() throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        try fileManager.removeItem(at: url)
    }

    func exists() -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
