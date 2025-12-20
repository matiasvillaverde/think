import Foundation
@testable import ModelDownloader
import Testing

@Suite("DownloadStatus Tests")
struct DownloadStatusTests {
    @Test("Initial status is notStarted")
    func testInitialStatus() {
        let status: DownloadStatus = DownloadStatus()
        #expect(status == .notStarted)
    }

    @Test("Status transitions from notStarted to downloading")
    func testStartDownload() {
        var status: DownloadStatus = DownloadStatus()
        status = .downloading(progress: 0.0)

        if case .downloading(let progress) = status {
            let expectedProgress: Double = 0.0
            #expect(progress == expectedProgress)
        } else {
            Issue.record("Expected downloading status")
        }
    }

    @Test("Status can be paused")
    func testPauseDownload() {
        var status: DownloadStatus = DownloadStatus()
        status = .downloading(progress: 0.5)
        status = .paused(progress: 0.5)

        if case .paused(let progress) = status {
            let expectedProgressPaused: Double = 0.5
            #expect(progress == expectedProgressPaused)
        } else {
            Issue.record("Expected paused status")
        }
    }

    @Test("Status transitions to completed")
    func testCompleteDownload() {
        var status: DownloadStatus = DownloadStatus()
        status = .downloading(progress: 1.0)
        status = .completed

        #expect(status == .completed)
    }

    @Test("Status can transition to failed")
    func testFailedDownload() {
        var status: DownloadStatus = DownloadStatus()
        status = .downloading(progress: 0.3)
        status = .failed(error: "Network error")

        if case .failed(let error) = status {
            let expectedError: String = "Network error"
            #expect(error == expectedError)
        } else {
            Issue.record("Expected failed status")
        }
    }

    @Test("isDownloading computed property")
    func testIsDownloading() {
        let notStarted: DownloadStatus = DownloadStatus()
        let expectedIsDownloadingNotStarted: Bool = false
        #expect(notStarted.isDownloading == expectedIsDownloadingNotStarted)

        let downloading: DownloadStatus = DownloadStatus.downloading(progress: 0.5)
        #expect(downloading.isDownloading == true)

        let paused: DownloadStatus = DownloadStatus.paused(progress: 0.5)
        #expect(paused.isDownloading == false)

        let completed: DownloadStatus = DownloadStatus.completed
        #expect(completed.isDownloading == false)

        let failed: DownloadStatus = DownloadStatus.failed(error: "Error")
        #expect(failed.isDownloading == false)
    }

    @Test("isPaused computed property")
    func testIsPaused() {
        let notStarted: DownloadStatus = DownloadStatus()
        #expect(notStarted.isPaused == false)

        let downloading: DownloadStatus = DownloadStatus.downloading(progress: 0.5)
        #expect(downloading.isPaused == false)

        let paused: DownloadStatus = DownloadStatus.paused(progress: 0.5)
        #expect(paused.isPaused == true)

        let completed: DownloadStatus = DownloadStatus.completed
        #expect(completed.isPaused == false)
    }

    @Test("isCompleted computed property")
    func testIsCompleted() {
        let notStarted: DownloadStatus = DownloadStatus()
        #expect(notStarted.isCompleted == false)

        let downloading: DownloadStatus = DownloadStatus.downloading(progress: 0.5)
        #expect(downloading.isCompleted == false)

        let completed: DownloadStatus = DownloadStatus.completed
        #expect(completed.isCompleted == true)
    }

    @Test("progress computed property")
    func testProgress() {
        let notStarted: DownloadStatus = DownloadStatus()
        #expect(notStarted.progress == 0.0)

        let downloading: DownloadStatus = DownloadStatus.downloading(progress: 0.5)
        #expect(downloading.progress == 0.5)

        let paused: DownloadStatus = DownloadStatus.paused(progress: 0.7)
        #expect(paused.progress == 0.7)

        let completed: DownloadStatus = DownloadStatus.completed
        #expect(completed.progress == 1.0)

        let failed: DownloadStatus = DownloadStatus.failed(error: "Error")
        #expect(failed.progress == 0.0)
    }

    @Test("Equatable conformance")
    func testEquatable() {
        let status1: DownloadStatus = DownloadStatus.downloading(progress: 0.5)
        let status2: DownloadStatus = DownloadStatus.downloading(progress: 0.5)
        let status3: DownloadStatus = DownloadStatus.downloading(progress: 0.6)

        #expect(status1 == status2)
        #expect(status1 != status3)

        let paused1: DownloadStatus = DownloadStatus.paused(progress: 0.5)
        let paused2: DownloadStatus = DownloadStatus.paused(progress: 0.5)

        #expect(paused1 == paused2)
        #expect(paused1 != status1)
    }

    @Test("Codable conformance")
    func testCodable() throws {
        let testCases: [DownloadStatus] = [
            .notStarted,
            .downloading(progress: 0.5),
            .paused(progress: 0.7),
            .completed,
            .failed(error: "Test error")
        ]

        for original: DownloadStatus in testCases {
            let encoder: JSONEncoder = JSONEncoder()
            let data: Data = try encoder.encode(original)

            let decoder: JSONDecoder = JSONDecoder()
            let decoded: DownloadStatus = try decoder.decode(DownloadStatus.self, from: data)

            #expect(decoded == original)
        }
    }
}
