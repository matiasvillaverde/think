import Abstractions
@testable import ModelDownloader
import Testing

@Suite("DownloadProgress Tests")
internal struct DownloadProgressTests {
    @Test("Initial progress creation")
    func testInitialProgress() {
        let progress: DownloadProgress = DownloadProgress.initial(totalBytes: 1_000, totalFiles: 5)

        #expect(progress.bytesDownloaded == 0)
        #expect(progress.totalBytes == 1_000)
        #expect(progress.filesCompleted == 0)
        #expect(progress.totalFiles == 5)
        #expect(progress.fractionCompleted == 0.0)
        #expect(progress.percentage == 0.0)
        #expect(!progress.isComplete)
    }

    @Test("Completed progress creation")
    func testCompletedProgress() {
        let progress: DownloadProgress = DownloadProgress.completed(
            totalBytes: 1_000,
            totalFiles: 5
        )

        #expect(progress.bytesDownloaded == 1_000)
        #expect(progress.totalBytes == 1_000)
        #expect(progress.filesCompleted == 5)
        #expect(progress.totalFiles == 5)
        #expect(progress.fractionCompleted == 1.0)
        #expect(progress.percentage == 100.0)
        #expect(progress.isComplete)
    }

    @Test("Progress calculations")
    func testProgressCalculations() {
        let progress: DownloadProgress = DownloadProgress(
            bytesDownloaded: 250,
            totalBytes: 1_000,
            filesCompleted: 1,
            totalFiles: 4
        )

        #expect(progress.fractionCompleted == 0.25)
        #expect(progress.percentage == 25.0)
        #expect(!progress.isComplete)
    }

    @Test("Progress updating with bytes")
    func testProgressUpdatingWithBytes() {
        let initial: DownloadProgress = DownloadProgress.initial(totalBytes: 1_000, totalFiles: 3)
        let updated: DownloadProgress = initial.updating(
            bytesDownloaded: 500,
            currentFileName: "model.safetensors"
        )

        #expect(updated.bytesDownloaded == 500)
        #expect(updated.totalBytes == 1_000)
        #expect(updated.filesCompleted == 0) // Files completed unchanged
        #expect(updated.totalFiles == 3)
        #expect(updated.currentFileName == "model.safetensors")
        #expect(updated.fractionCompleted == 0.5)
    }

    @Test("File completion")
    func testFileCompletion() {
        let initial: DownloadProgress = DownloadProgress(
            bytesDownloaded: 333,
            totalBytes: 1_000,
            filesCompleted: 0,
            totalFiles: 3,
            currentFileName: "file1.json"
        )

        let completed: DownloadProgress = initial.completingFile()

        #expect(completed.bytesDownloaded == 333)
        #expect(completed.totalBytes == 1_000)
        #expect(completed.filesCompleted == 1)
        #expect(completed.totalFiles == 3)
        #expect(completed.currentFileName == nil) // Cleared when file completed
    }

    @Test("Zero total bytes handling")
    func testZeroTotalBytesHandling() {
        let progress: DownloadProgress = DownloadProgress(
            bytesDownloaded: 0,
            totalBytes: 0,
            filesCompleted: 0,
            totalFiles: 1
        )

        #expect(progress.fractionCompleted == 0.0)
        #expect(progress.percentage == 0.0)
    }

    @Test("Progress description formatting")
    func testProgressDescription() {
        let progress: DownloadProgress = DownloadProgress(
            bytesDownloaded: 512_000, // 512 KB
            totalBytes: 1_024_000,    // 1 MB
            filesCompleted: 1,
            totalFiles: 3,
            currentFileName: "model.safetensors"
        )

        let description: String = progress.description

        #expect(description.contains("KB")) // Contains byte formatting
        #expect(description.contains("50.0%")) // Contains percentage
        #expect(description.contains("1/3 files")) // Contains file progress
        #expect(description.contains("model.safetensors")) // Contains current file
    }

    @Test("Progress description without current file")
    func testProgressDescriptionWithoutCurrentFile() {
        let progress: DownloadProgress = DownloadProgress(
            bytesDownloaded: 256_000,
            totalBytes: 1_024_000,
            filesCompleted: 2,
            totalFiles: 4
        )

        let description: String = progress.description

        #expect(description.contains("25.0%"))
        #expect(description.contains("2/4 files"))
        #expect(!description.contains(" - model.")) // No current file mentioned
    }

    @Test("Progress equality")
    func testProgressEquality() {
        let progress1: DownloadProgress = DownloadProgress(
            bytesDownloaded: 500,
            totalBytes: 1_000,
            filesCompleted: 1,
            totalFiles: 2,
            currentFileName: "test.json"
        )

        let progress2: DownloadProgress = DownloadProgress(
            bytesDownloaded: 500,
            totalBytes: 1_000,
            filesCompleted: 1,
            totalFiles: 2,
            currentFileName: "test.json"
        )

        let progress3: DownloadProgress = DownloadProgress(
            bytesDownloaded: 600,
            totalBytes: 1_000,
            filesCompleted: 1,
            totalFiles: 2,
            currentFileName: "test.json"
        )

        #expect(progress1 == progress2)
        #expect(progress1 != progress3)
    }

    @Test("Progress is Sendable")
    func testSendable() {
        let progress: any Sendable = DownloadProgress.initial(totalBytes: 1_000, totalFiles: 1)
        #expect(progress is DownloadProgress)
    }
}
