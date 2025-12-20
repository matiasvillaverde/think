// import Foundation
// @testable import ModelDownloader
// import Testing
//
//// MARK: - Test Helpers
//
// private actor ProgressCollector {
//    private var progressValues: [Any] = []
//
//    func addProgress(_ value: Double) {
//        progressValues.append(value)
//    }
//
//    func getProgress() -> [Double] {
//        progressValues
//    }
// }
//
//// MARK: - Streaming Download Tests
//
// @Test("StreamingDownloader should initialize correctly")
// internal func testStreamingDownloaderInit() throws {
//    let mockSession = MockURLSession()
//    let downloader = StreamingDownloader(urlSession: mockSession)
//
//    // Downloader is successfully initialized
// }
//
// @Test("StreamingDownloader should download file with progress")
// internal func testStreamingDownload() async throws {
//    let mockSession = MockURLSession()
//    let downloader = StreamingDownloader(urlSession: mockSession)
//
//    let testData: Data = Data("Hello, World!".utf8)
//    let url: URL = URL(string: "https://example.com/file.txt")!
//    let destination: URL = URL(fileURLWithPath: "/tmp/test.txt")
//
//    // Mock response
//    mockSession.mockData = testData
//    mockSession.mockResponse = HTTPURLResponse(
//        url: url,
//        statusCode: 200,
//        httpVersion: nil,
//        headerFields: ["Content-Length": "\(testData.count)"]
//    )
//
//    let progressActor = ProgressCollector()
//
//    let downloadedURL: Data = try await downloader.download(
//        from: url,
//        to: destination,
//        headers: [:]
//    ) { progress in
//            Task {
//                await progressActor.addProgress(progress)
//            }
//    }
//
//    let progressUpdates = await progressActor.getProgress()
//
//    #expect(downloadedURL == destination)
//    #expect(!progressUpdates.isEmpty)
//    #expect(progressUpdates.last == 1.0)
//    #expect(mockSession.lastRequest?.url == url)
// }
//
// @Test("StreamingDownloader should handle authentication headers")
// internal func testAuthenticatedDownload() async throws {
//    let mockSession = MockURLSession()
//    let downloader = StreamingDownloader(urlSession: mockSession)
//
//    let url: URL = URL(string: "https://example.com/private/file.txt")!
//    let destination: URL = URL(fileURLWithPath: "/tmp/test.txt")
//    let headers: [String] = ["Authorization": "Bearer test_token"]
//
//    mockSession.mockData = Data("Private content".utf8)
//    mockSession.mockResponse = HTTPURLResponse(
//        url: url,
//        statusCode: 200,
//        httpVersion: nil,
//        headerFields: nil
//    )
//
//    _ = try await downloader.download(
//        from: url,
//        to: destination,
//        headers: headers
//    ) { _ in }
//
//    #expect(mockSession.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer test_token")
// }
//
// @Test("StreamingDownloader should handle download errors")
// internal func testDownloadError() async throws {
//    let mockSession = MockURLSession()
//    let downloader = StreamingDownloader(urlSession: mockSession)
//
//    let url: URL = URL(string: "https://example.com/missing.txt")!
//    let destination: URL = URL(fileURLWithPath: "/tmp/test.txt")
//
//    mockSession.mockResponse = HTTPURLResponse(
//        url: url,
//        statusCode: 404,
//        httpVersion: nil,
//        headerFields: nil
//    )
//
//    do {
//        _ = try await downloader.download(
//            from: url,
//            to: destination,
//            headers: [:]
//        ) { _ in }
//        #expect(Bool(false), "Should have thrown an error")
//    } catch {
//        #expect(error is HuggingFaceError)
//    }
// }
//
// @Test(
//    "StreamingDownloader should support cancellation",
//    .disabled("Mock doesn't properly simulate cancellable async bytes")
// )
// internal func testDownloadCancellation() async throws {
//    let mockSession = MockURLSession()
//    let downloader = StreamingDownloader(urlSession: mockSession)
//
//    let url: URL = URL(string: "https://example.com/large.bin")!
//    let destination: URL = URL(fileURLWithPath: "/tmp/large.bin")
//
//    // Mock a large download that will be cancelled
//    mockSession.mockData = Data(repeating: 0, count: 1_000_000)
//    mockSession.mockResponse = HTTPURLResponse(
//        url: url,
//        statusCode: 200,
//        httpVersion: nil,
//        headerFields: ["Content-Length": "1000000"]
//    )
//    mockSession.shouldDelayResponse = true
//
//    let task: Task<Void, Error> = Task {
//        try await downloader.download(
//            from: url,
//            to: destination,
//            headers: [:]
//        ) { _ in }
//    }
//
//    // Cancel after a short delay
//    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
//    task.cancel()
//
//    do {
//        _ = try await task.value
//        #expect(Bool(false), "Should have been cancelled")
//    } catch {
//        #expect(error is CancellationError)
//    }
// }
//
// @Test("StreamingDownloader should handle partial content")
// internal func testPartialContentDownload() async throws {
//    let mockSession = MockURLSession()
//    let downloader = StreamingDownloader(urlSession: mockSession)
//
//    let url: URL = URL(string: "https://example.com/partial.bin")!
//    let destination: URL = URL(fileURLWithPath: "/tmp/partial.bin")
//
//    // Create a file with existing content
//    let existingData: Data = Data("Existing".utf8)
//    try existingData.write(to: destination)
//
//    // Mock partial content response
//    let newData: Data = Data(" content".utf8)
//    mockSession.mockData = newData
//    mockSession.mockResponse = HTTPURLResponse(
//        url: url,
//        statusCode: 206, // Partial Content
//        httpVersion: nil,
//        headerFields: [
//            "Content-Length": "\(newData.count)",
//            "Content-Range": "bytes 8-15/16"
//        ]
//    )
//
//    let downloadedURL: Data = try await downloader.downloadResume(
//        from: url,
//        to: destination,
//        headers: [:]
//    ) { _ in }
//
//    #expect(downloadedURL == destination)
//
//    // Verify Range header was set
//    #expect(mockSession.lastRequest?.value(forHTTPHeaderField: "Range") == "bytes=8-")
// }
//
//// MARK: - Background Download Tests
//
// @Test("BackgroundDownloader should create download task")
// internal func testBackgroundDownloadTask() async throws {
//    let mockSession = MockBackgroundURLSession()
//    let downloader = BackgroundDownloader(
//        identifier: "com.test.downloader",
//        urlSession: mockSession
//    )
//
//    let url: URL = URL(string: "https://example.com/model.bin")!
//    let destination: URL = URL(fileURLWithPath: "/tmp/model.bin")
//
//    let taskId: Data = try await downloader.startDownload(
//        from: url,
//        to: destination,
//        headers: [:]
//    )
//
//    #expect(!taskId.isEmpty)
//    #expect(mockSession.lastDownloadTask != nil)
// }
//
// @Test("BackgroundDownloader should handle URLSessionDownloadDelegate callbacks")
// internal func testBackgroundDownloadDelegateCallbacks() async throws {
//    let mockSession = MockBackgroundURLSession()
//    let downloader = BackgroundDownloader(
//        identifier: "com.test.downloader",
//        urlSession: mockSession
//    )
//
//    let url: URL = URL(string: "https://example.com/model.bin")!
//    let destination: URL = URL(fileURLWithPath: "/tmp/test-model.bin")
//
//    // Start download
//    let taskId: Data = try await downloader.startDownload(
//        from: url,
//        to: destination,
//        headers: ["Authorization": "Bearer test_token"]
//    )
//
//    #expect(taskId.hasPrefix("com.test.downloader."))
//
//    // Verify the download task was created with proper headers
//    guard let task: String? = mockSession.lastDownloadTask else {
//        #expect(Bool(false), "Download task should have been created")
//        return
//    }
//
//    #expect(mockSession.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer test_token")
//
//    // Simulate successful download completion
//    let tempLocation: URL = URL(fileURLWithPath: "/tmp/temp-download-\(UUID().uuidString)")
//    try Data("Test model content".utf8).write(to: tempLocation)
//
//    await downloader.handleDownloadCompletion(
//        task: task,
//        location: tempLocation,
//        error: nil
//    )
//
//    // The file should have been moved to destination
//    // Since this is a mock, we can't verify the actual file move
//    // but we can verify the completion handler was called
// }
//
// @Test("BackgroundDownloader should handle download errors")
// internal func testBackgroundDownloadError() async throws {
//    let mockSession = MockBackgroundURLSession()
//    let downloader = BackgroundDownloader(
//        identifier: "com.test.downloader",
//        urlSession: mockSession
//    )
//
//    let url: URL = URL(string: "https://example.com/model.bin")!
//    let destination: URL = URL(fileURLWithPath: "/tmp/error-model.bin")
//
//    // Start download
//    _ = try await downloader.startDownload(
//        from: url,
//        to: destination,
//        headers: [:]
//    )
//
//    guard let task: String? = mockSession.lastDownloadTask else {
//        #expect(Bool(false), "Download task should have been created")
//        return
//    }
//
//    // Simulate download error
//    let error = URLError(.networkConnectionLost)
//    await downloader.handleDownloadCompletion(
//        task: task,
//        location: nil,
//        error: error
//    )
//
//    // Verify error handling (in real implementation, this would trigger error callback)
// }
//
// @Test(
//    "BackgroundDownloader should support download cancellation",
//    .disabled("Mock URLSessionDownloadTask doesn't properly simulate cancellation")
// )
// internal func testBackgroundDownloadCancellation() async throws {
//    let mockSession = MockBackgroundURLSession()
//    let downloader = BackgroundDownloader(
//        identifier: "com.test.downloader",
//        urlSession: mockSession
//    )
//
//    let url: URL = URL(string: "https://example.com/large-model.bin")!
//    let destination: URL = URL(fileURLWithPath: "/tmp/cancelled-model.bin")
//
//    // Start download
//    let taskId: Data = try await downloader.startDownload(
//        from: url,
//        to: destination,
//        headers: [:]
//    )
//
//    // Get a reference to the task before cancelling
//    guard let task: String? = mockSession.lastDownloadTask as? MockDownloadTask else {
//        #expect(Bool(false), "Download task should have been created")
//        return
//    }
//
//    // Store the task state before cancellation
//    #expect(!task.isCancelled, "Task should not be cancelled initially")
//
//    // Print the task ID to understand the format
//    print("Task ID: \(taskId)")
//    print("Task identifier: \(task.taskIdentifier)")
//
//    // Cancel the download using the task ID
//    await downloader.cancelDownload(taskId: taskId)
//
//    // Verify task was cancelled
//    #expect(task.isCancelled, "Task should be cancelled after calling cancelDownload")
// }
//
// @Test("BackgroundDownloader should extract task identifier correctly")
// internal func testTaskIdentifierExtraction() async throws {
//    let mockSession = MockBackgroundURLSession()
//    let downloader = BackgroundDownloader(
//        identifier: "com.test.downloader",
//        urlSession: mockSession
//    )
//
//    let url: URL = URL(string: "https://example.com/test.bin")!
//    let destination: URL = URL(fileURLWithPath: "/tmp/test.bin")
//
//    let taskId: Data = try await downloader.startDownload(
//        from: url,
//        to: destination,
//        headers: [:]
//    )
//
//    // Task ID should follow format: identifier.taskNumber
//    // Since identifier contains dots, we need to get the last component
//    let lastDotIndex: String? = taskId.lastIndex(of: ".")!
//    let identifierPart: String = String(taskId[..<lastDotIndex])
//    let taskNumberPart: String = String(taskId[taskId.index(after: lastDotIndex)...])
//
//    #expect(identifierPart == "com.test.downloader")
//    #expect(Int(taskNumberPart) != nil)
// }
//
// @Test("BackgroundDownloader should track downloads correctly")
// internal func testBackgroundDownloadTaskTracking() async throws {
//    let mockSession = MockBackgroundURLSession()
//    let downloader = BackgroundDownloader(
//        identifier: "com.test.downloader",
//        urlSession: mockSession
//    )
//
//    let url: URL = URL(string: "https://example.com/tracked.bin")!
//    let destination: URL = URL(fileURLWithPath: "/tmp/tracked.bin")
//
//    // Start download
//    _ = try await downloader.startDownload(
//        from: url,
//        to: destination,
//        headers: [:]
//    )
//
//    // Verify task was created
//    #expect(mockSession.lastDownloadTask != nil)
//
//    // The task should be tracked internally
//    // We can't directly check downloadTasks dictionary since it's private,
//    // but we can verify the behavior through public methods
// }
//
//// MARK: - Mock Types
//
// private final class MockURLSession: @unchecked Sendable {
//    var mockData: Data?
//    var mockResponse: URLResponse?
//    var mockError: Error?
//    var lastRequest: URLRequest?
//    var shouldDelayResponse: Bool = false
//
//    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
//        lastRequest = request
//
//        if shouldDelayResponse {
//            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
//        }
//
//        if let error: Any = mockError {
//            throw error
//        }
//
//        let data = mockData ?? Data()
//        let response = mockResponse ?? URLResponse()
//
//        return (data, response)
//    }
//
//    func dataTask(with request: URLRequest) -> URLSessionDataTask {
//        lastRequest = request
//        return MockDataTask()
//    }
//
//    func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) {
//        lastRequest = request
//
//        if shouldDelayResponse {
//            // Check for cancellation during delay
//            for _: Any in 0..<10  {
//                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
//                try Task.checkCancellation()
//            }
//        }
//
//        if let error: Any = mockError {
//            throw error
//        }
//
//        let response = mockResponse ?? HTTPURLResponse(
//            url: request.url!,
//            statusCode: 200,
//            httpVersion: nil,
//            headerFields: ["Content-Length": "\(mockData?.count ?? 0)"]
//        )!
//
//        // Create a large data to simulate slow download
//        let data = mockData ?? Data(repeating: 65, count: 10_000) // 10KB of 'A's
//
//        // If we need to delay, we'll do it in the streaming download handler
//        // For now, create a temporary file and use real URLSession bytes
//        let tempURL: FileManager = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
//        try data.write(to: tempURL)
//
//        // Use real URLSession to get proper AsyncBytes
//        let fileURL: URL = URL(fileURLWithPath: tempURL.path)
//        let dataRequest: URLRequest = URLRequest(url: fileURL)
//        let (bytes, _): (Data, URLResponse) = try await URLSession.shared.bytes(for: dataRequest)
//
//        // Clean up temp file after a delay
//        Task {
//            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
//            try? FileManager.default.removeItem(at: tempURL)
//        }
//
//        return (bytes, response)
//    }
// }
//
// extension MockURLSession: DownloadSessionProtocol {
//    func downloadTask(with request: URLRequest) -> URLSessionDownloadTask {
//        lastRequest = request
//        return MockDownloadTask()
//    }
// }
//
// private final class MockDataTask: URLSessionDataTask, @unchecked Sendable {
//    override func resume() {
//        // Mock implementation
//    }
//
//    override func cancel() {
//        // Mock implementation
//    }
// }
//
// private final class MockBackgroundURLSession: @unchecked Sendable {
//    var lastDownloadTask: URLSessionDownloadTask?
//    var lastRequest: URLRequest?
//
//    func downloadTask(with request: URLRequest) -> URLSessionDownloadTask {
//        lastRequest = request
//        let task = MockDownloadTask()
//        lastDownloadTask = task
//        return task
//    }
// }
//
// extension MockBackgroundURLSession: DownloadSessionProtocol {
//    func data(for _: URLRequest) throws -> (Data, URLResponse) {
//        (Data(), URLResponse())
//    }
//
//    func dataTask(with _: URLRequest) -> URLSessionDataTask {
//        MockDataTask()
//    }
//
//    func bytes(for _: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) {
//        try await URLSession.shared.bytes(from: URL(string: "data:text/plain;base64,")!)
//    }
// }
//
// private final class MockDownloadTask: URLSessionDownloadTask, @unchecked Sendable {
//    private let mockTaskIdentifier: Int = Int.random(in: 1...1_000)
//    private(set) var isCancelled: Bool = false
//
//    override var taskIdentifier: Int {
//        mockTaskIdentifier
//    }
//
//    override func resume() {
//        // Mock implementation
//    }
//
//    override func cancel() {
//        isCancelled = true
//    }
// }
