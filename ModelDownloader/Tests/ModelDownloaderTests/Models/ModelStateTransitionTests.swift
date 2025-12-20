import Foundation
@testable import ModelDownloader
import Testing

@Suite("Model State Transition Tests")
struct ModelStateTransitionTests {
    @Test("Valid download status transitions")
    func testValidDownloadTransitions() {
        // notStarted -> downloading
        #expect(DownloadStatus.isValidTransition(from: .notStarted, to: .downloading(progress: 0)))

        // downloading -> paused
        #expect(DownloadStatus.isValidTransition(from: .downloading(progress: 0.5), to: .paused(progress: 0.5)))

        // paused -> downloading
        #expect(DownloadStatus.isValidTransition(from: .paused(progress: 0.5), to: .downloading(progress: 0.5)))

        // downloading -> completed
        #expect(DownloadStatus.isValidTransition(from: .downloading(progress: 1.0), to: .completed))

        // any -> failed
        #expect(DownloadStatus.isValidTransition(from: .notStarted, to: .failed(error: "Error")))
        #expect(DownloadStatus.isValidTransition(from: .downloading(progress: 0.5), to: .failed(error: "Error")))
        #expect(DownloadStatus.isValidTransition(from: .paused(progress: 0.5), to: .failed(error: "Error")))
    }

    @Test("Invalid download status transitions")
    func testInvalidDownloadTransitions() {
        // completed -> downloading (can't re-download)
        #expect(!DownloadStatus.isValidTransition(from: .completed, to: .downloading(progress: 0)))

        // notStarted -> paused (can't pause before starting)
        #expect(!DownloadStatus.isValidTransition(from: .notStarted, to: .paused(progress: 0)))

        // notStarted -> completed (can't complete without downloading)
        #expect(!DownloadStatus.isValidTransition(from: .notStarted, to: .completed))

        // failed -> downloading (must reset first)
        #expect(!DownloadStatus.isValidTransition(from: .failed(error: "Error"), to: .downloading(progress: 0)))
    }

    @Test("Valid availability transitions")
    func testValidAvailabilityTransitions() {
        // notReady -> loading
        #expect(ModelAvailability.isValidTransition(from: .notReady, to: .loading(progress: 0)))

        // loading -> ready
        #expect(ModelAvailability.isValidTransition(from: .loading(progress: 1.0), to: .ready))

        // ready -> generating
        #expect(ModelAvailability.isValidTransition(from: .ready, to: .generating))

        // generating -> ready
        #expect(ModelAvailability.isValidTransition(from: .generating, to: .ready))

        // any -> error
        #expect(ModelAvailability.isValidTransition(from: .notReady, to: .error("Error")))
        #expect(ModelAvailability.isValidTransition(from: .loading(progress: 0.5), to: .error("Error")))
        #expect(ModelAvailability.isValidTransition(from: .ready, to: .error("Error")))
        #expect(ModelAvailability.isValidTransition(from: .generating, to: .error("Error")))
    }

    @Test("Invalid availability transitions")
    func testInvalidAvailabilityTransitions() {
        // notReady -> ready (must load first)
        #expect(!ModelAvailability.isValidTransition(from: .notReady, to: .ready))

        // notReady -> generating (must be ready first)
        #expect(!ModelAvailability.isValidTransition(from: .notReady, to: .generating))

        // loading -> generating (must be ready first)
        #expect(!ModelAvailability.isValidTransition(from: .loading(progress: 0.5), to: .generating))

        // error -> ready (must reload)
        #expect(!ModelAvailability.isValidTransition(from: .error("Error"), to: .ready))
    }

    @Test("Combined state transitions")
    func testCombinedStateTransitions() {
        // Test common workflows

        // Download workflow
        var download: DownloadStatus = DownloadStatus()
        #expect(download == .notStarted)

        download = .downloading(progress: 0.0)
        #expect(download.isDownloading)

        download = .downloading(progress: 0.5)
        #expect(download.progress == 0.5)

        download = .paused(progress: 0.5)
        #expect(download.isPaused)

        download = .downloading(progress: 0.5)
        download = .downloading(progress: 1.0)
        download = .completed
        #expect(download.isCompleted)

        // Load workflow
        var availability: ModelAvailability = ModelAvailability()
        #expect(availability == .notReady)

        availability = .loading(progress: 0.0)
        #expect(availability.isLoading)

        availability = .loading(progress: 1.0)
        availability = .ready
        #expect(availability.isReady)

        availability = .generating
        #expect(availability.isGenerating)
        #expect(availability.isReady) // Still ready while generating

        availability = .ready
        #expect(!availability.isGenerating)
    }
}
