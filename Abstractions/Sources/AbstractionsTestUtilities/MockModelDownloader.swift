import Abstractions
import Foundation

/// Mock implementation of ModelDownloaderProtocol for testing
/// 
/// This mock provides configurable responses and tracks method calls for verification.
/// Following the pattern established by MockLLMSession.
public final class MockModelDownloader: ModelDownloaderProtocol, @unchecked Sendable {
    // MARK: - Method Call Tracking

    /// Tracks all method calls for verification in tests
    public struct MethodCall: Equatable, Sendable {
        public let method: String
        public let parameters: [String: String]
        public let timestamp: Date

        public init(method: String, parameters: [String: String] = [:]) {
            self.method = method
            self.parameters = parameters
            self.timestamp = Date()
        }

        public static func == (lhs: MethodCall, rhs: MethodCall) -> Bool {
            lhs.method == rhs.method && lhs.parameters == rhs.parameters
        }
    }

    // MARK: - Configurable Model State

    /// Configuration for a model's location and metadata
    public struct ModelLocationConfig: Sendable {
        public let location: URL
        public let exists: Bool
        public let size: Int64?
        public let modelInfo: ModelInfo?

        public init(
            location: URL,
            exists: Bool = true,
            size: Int64? = nil,
            modelInfo: ModelInfo? = nil
        ) {
            self.location = location
            self.exists = exists
            self.size = size
            self.modelInfo = modelInfo
        }
    }

    // MARK: - Constants

    private static let kKilobyte: Int64 = 1_024
    private static let kMegabyte: Int64 = kKilobyte * kKilobyte
    private static let kGigabyte: Int64 = kMegabyte * kKilobyte
    private static let kDefaultModelSize: Int64 = kMegabyte * 100
    private static let kDefaultDiskSpace: Int64 = kGigabyte * 10

    // MARK: - State Management

    private let lock = NSLock()
    private var modelConfigs: [String: ModelLocationConfig] = [:]
    private var _methodCalls: [MethodCall] = []

    // MARK: - Public Properties

    /// All method calls made to this mock
    public var methodCalls: [MethodCall] {
        lock.lock()
        defer { lock.unlock() }
        return _methodCalls
    }

    /// Configurable behaviors
    public var shouldFailDownload: Bool = false
    public var shouldFailValidation: Bool = false
    public var availableDiskSpaceValue: Int64? = kDefaultDiskSpace
    public var notificationPermissionResult: Bool = true
    public var recommendedBackend: SendableModel.Backend = .mlx

    /// Background download tracking
    public private(set) var handleBackgroundDownloadCompletionCalled: Bool = false
    public private(set) var lastCompletionIdentifier: String?
    public private(set) var backgroundDownloadHandles: [BackgroundDownloadHandle] = []

    /// Configurable return value for backgroundDownloadStatus
    public var backgroundDownloadStatusToReturn: [BackgroundDownloadStatus] = []

    // MARK: - Initialization

    public init() {
        // Empty initializer
    }

    deinit {
        // Required by linting rules
    }

    // MARK: - Setup Methods

    /// Configure a model with specific location and metadata
    public func configureModel(
        for repositoryId: String,
        location: URL,
        exists: Bool = true,
        size: Int64? = nil,
        modelInfo: ModelInfo? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }

        let config = ModelLocationConfig(
            location: location,
            exists: exists,
            size: size ?? Self.kDefaultModelSize,
            modelInfo: modelInfo
        )
        modelConfigs[repositoryId] = config
    }

    /// Reset all state for test isolation
    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        modelConfigs.removeAll()
        _methodCalls.removeAll()
        shouldFailDownload = false
        shouldFailValidation = false
        availableDiskSpaceValue = Self.kDefaultDiskSpace
        notificationPermissionResult = true
        recommendedBackend = .mlx
        handleBackgroundDownloadCompletionCalled = false
        lastCompletionIdentifier = nil
        backgroundDownloadHandles.removeAll()
        backgroundDownloadStatusToReturn.removeAll()
    }

    // MARK: - Helper Methods

    private func trackCall(_ method: String, parameters: [String: String] = [:]) {
        lock.lock()
        defer { lock.unlock() }
        _methodCalls.append(MethodCall(method: method, parameters: parameters))
    }

    // MARK: - Background Downloads

    public func downloadModelInBackground(
        sendableModel: ModelLocation,
        options: BackgroundDownloadOptions
    ) -> AsyncThrowingStream<BackgroundDownloadEvent, Error> {
        trackCall("downloadModelInBackground", parameters: [
            "model": sendableModel,
            "enableCellular": String(options.enableCellular)
        ])

        return AsyncThrowingStream<BackgroundDownloadEvent, Error> { continuation in
            if shouldFailDownload {
                continuation.finish(throwing: MockModelDownloaderError.downloadFailed)
            } else {
                self.handleSuccessfulDownload(sendableModel: sendableModel, continuation: continuation)
            }
        }
    }

    private func handleSuccessfulDownload(
        sendableModel: ModelLocation,
        continuation: AsyncThrowingStream<BackgroundDownloadEvent, Error>.Continuation
    ) {
        lock.lock()
        let config = modelConfigs[sendableModel]
        lock.unlock()

        guard let config else {
            continuation.finish()
            return
        }

        let handle = BackgroundDownloadHandle(
            id: UUID(),
            modelId: sendableModel,
            backend: recommendedBackend,
            sessionIdentifier: "mock-session"
        )

        lock.lock()
        backgroundDownloadHandles.append(handle)
        lock.unlock()

        continuation.yield(.handle(handle))

        if let modelInfo = config.modelInfo {
            continuation.yield(.completed(modelInfo))
        } else {
            let modelInfo = ModelInfo(
                id: UUID(),
                name: sendableModel,
                backend: recommendedBackend,
                location: config.location,
                totalSize: config.size ?? Self.kDefaultModelSize,
                downloadDate: Date()
            )
            continuation.yield(.completed(modelInfo))
        }

        continuation.finish()
    }

    public func resumeBackgroundDownloads() throws -> [BackgroundDownloadHandle] {
        trackCall("resumeBackgroundDownloads")
        lock.lock()
        defer { lock.unlock() }
        return backgroundDownloadHandles
    }

    public func backgroundDownloadStatus() -> [BackgroundDownloadStatus] {
        trackCall("backgroundDownloadStatus")
        lock.lock()
        defer { lock.unlock() }

        // Return configured status if available
        if !backgroundDownloadStatusToReturn.isEmpty {
            return backgroundDownloadStatusToReturn
        }

        // Otherwise return default based on handles
        return backgroundDownloadHandles.map { handle in
            BackgroundDownloadStatus(
                handle: handle,
                state: .completed,
                progress: 1.0
            )
        }
    }

    public func cancelBackgroundDownload(_ handle: BackgroundDownloadHandle) {
        trackCall("cancelBackgroundDownload", parameters: ["handleId": handle.id.uuidString])
        lock.lock()
        defer { lock.unlock() }
        backgroundDownloadHandles.removeAll { $0.id == handle.id }
    }

    // MARK: - Model Management

    public func listDownloadedModels() throws -> [ModelInfo] {
        trackCall("listDownloadedModels")
        lock.lock()
        defer { lock.unlock() }

        return modelConfigs.compactMap { key, config in
            config.modelInfo ?? ModelInfo(
                id: UUID(),
                name: key,
                backend: recommendedBackend,
                location: config.location,
                totalSize: config.size ?? Self.kDefaultModelSize,
                downloadDate: Date()
            )
        }
    }

    public func modelExists(model: ModelLocation) -> Bool {
        trackCall("modelExists", parameters: ["model": model])
        lock.lock()
        defer { lock.unlock() }
        return modelConfigs[model]?.exists ?? false
    }

    public func deleteModel(model: ModelLocation) throws {
        trackCall("deleteModel", parameters: ["model": model])
        lock.lock()
        defer { lock.unlock() }
        modelConfigs.removeValue(forKey: model)
    }

    public func getModelSize(model: ModelLocation) -> Int64? {
        trackCall("getModelSize", parameters: ["model": model])
        lock.lock()
        defer { lock.unlock() }
        return modelConfigs[model]?.size
    }

    // MARK: - File System Operations

    public func getModelLocation(for model: ModelLocation) -> URL? {
        trackCall("getModelLocation", parameters: ["model": model])
        lock.lock()
        defer { lock.unlock() }
        return modelConfigs[model]?.location
    }

    public func getModelFileURL(for model: ModelLocation, fileName: String) -> URL? {
        trackCall("getModelFileURL", parameters: ["model": model, "fileName": fileName])
        lock.lock()
        defer { lock.unlock() }

        guard let location = modelConfigs[model]?.location else {
            return nil
        }
        return location.appendingPathComponent(fileName)
    }

    public func getModelFiles(for model: ModelLocation) -> [URL] {
        trackCall("getModelFiles", parameters: ["model": model])
        lock.lock()
        defer { lock.unlock() }

        guard let location = modelConfigs[model]?.location else {
            return []
        }

        return [
            location.appendingPathComponent("model.safetensors"),
            location.appendingPathComponent("config.json")
        ]
    }

    public func getModelInfo(for model: ModelLocation) -> ModelInfo? {
        trackCall("getModelInfo", parameters: ["model": model])
        lock.lock()
        defer { lock.unlock() }

        guard let config = modelConfigs[model] else {
            return nil
        }

        return config.modelInfo ?? ModelInfo(
            id: UUID(),
            name: model,
            backend: recommendedBackend,
            location: config.location,
            totalSize: config.size ?? Self.kDefaultModelSize,
            downloadDate: Date()
        )
    }

    // MARK: - Validation and Utilities

    public func validateModel(
        _ model: ModelLocation,
        backend: SendableModel.Backend
    ) throws -> ValidationResult {
        trackCall("validateModel", parameters: [
            "model": model,
            "backend": String(describing: backend)
        ])

        if shouldFailValidation {
            return ValidationResult(isValid: false, warnings: ["Validation failed"])
        }

        return ValidationResult(isValid: true, warnings: [])
    }

    public func getRecommendedBackend(for model: ModelLocation) -> SendableModel.Backend {
        trackCall("getRecommendedBackend", parameters: ["model": model])
        return recommendedBackend
    }

    public func availableDiskSpace() -> Int64? {
        trackCall("availableDiskSpace")
        return availableDiskSpaceValue
    }

    public func cleanupIncompleteDownloads() throws {
        trackCall("cleanupIncompleteDownloads")
        // No-op for mock
    }

    // MARK: - Notifications and Background Handling

    public func requestNotificationPermission() -> Bool {
        trackCall("requestNotificationPermission")
        return notificationPermissionResult
    }

    @preconcurrency
    public func handleBackgroundDownloadCompletion(
        identifier: String,
        completionHandler: @escaping @Sendable () -> Void
    ) {
        trackCall("handleBackgroundDownloadCompletion", parameters: ["identifier": identifier])

        lock.lock()
        handleBackgroundDownloadCompletionCalled = true
        lastCompletionIdentifier = identifier
        lock.unlock()

        completionHandler()
    }

    // MARK: - Download Management

    public func cancelDownload(for model: ModelLocation) {
        trackCall("cancelDownload", parameters: ["model": model])
        // No-op for mock
    }

    public func pauseDownload(for model: ModelLocation) {
        trackCall("pauseDownload", parameters: ["model": model])
        // No-op for mock
    }

    public func resumeDownload(for model: ModelLocation) {
        trackCall("resumeDownload", parameters: ["model": model])
        // No-op for mock
    }
}
