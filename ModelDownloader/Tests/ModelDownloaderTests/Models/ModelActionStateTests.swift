import Foundation
@testable import ModelDownloader
import Testing

@Suite("ModelActionState Tests")
struct ModelActionStateTests {
    @Test("Initial state is available")
    func testInitialState() {
        let state: ModelActionState = ModelActionState()
        #expect(state == .available)
    }

    @Test("State transitions from available to downloading")
    func testAvailableToDownloading() {
        var state: ModelActionState = ModelActionState()
        state = .downloading(progress: 0.0)

        if case .downloading(let progress) = state {
            #expect(progress == 0.0)
        } else {
            Issue.record("Expected downloading state")
        }
    }

    @Test("State transitions to paused")
    func testPausedState() {
        var state: ModelActionState = ModelActionState()
        state = .downloading(progress: 0.5)
        state = .paused(progress: 0.5)

        if case .paused(let progress) = state {
            #expect(progress == 0.5)
        } else {
            Issue.record("Expected paused state")
        }
    }

    @Test("State transitions to loading")
    func testLoadingState() {
        var state: ModelActionState = ModelActionState()
        state = .loading(progress: 0.0)

        if case .loading(let progress) = state {
            #expect(progress == 0.0)
        } else {
            Issue.record("Expected loading state")
        }
    }

    @Test("State transitions to ready")
    func testReadyState() {
        var state: ModelActionState = ModelActionState()
        state = .loading(progress: 1.0)
        state = .ready

        #expect(state == .ready)
    }

    @Test("State can show error")
    func testErrorState() {
        var state: ModelActionState = ModelActionState()
        state = .downloading(progress: 0.3)
        state = .error("Network failure")

        if case .error(let message) = state {
            #expect(message == "Network failure")
        } else {
            Issue.record("Expected error state")
        }
    }

    @Test("primaryAction computed property")
    func testPrimaryAction() {
        let available: ModelActionState = ModelActionState.available
        #expect(available.primaryAction == .download)

        let downloading: ModelActionState = ModelActionState.downloading(progress: 0.5)
        #expect(downloading.primaryAction == .pause)

        let paused: ModelActionState = ModelActionState.paused(progress: 0.5)
        #expect(paused.primaryAction == .resume)

        let loading: ModelActionState = ModelActionState.loading(progress: 0.5)
        #expect(loading.primaryAction == nil)

        let ready: ModelActionState = ModelActionState.ready
        #expect(ready.primaryAction == .open)

        let error: ModelActionState = ModelActionState.error("Error")
        #expect(error.primaryAction == .retry)
    }

    @Test("secondaryAction computed property")
    func testSecondaryAction() {
        let available: ModelActionState = ModelActionState.available
        #expect(available.secondaryAction == nil)

        let downloading: ModelActionState = ModelActionState.downloading(progress: 0.5)
        #expect(downloading.secondaryAction == .cancel)

        let paused: ModelActionState = ModelActionState.paused(progress: 0.5)
        #expect(paused.secondaryAction == .cancel)

        let loading: ModelActionState = ModelActionState.loading(progress: 0.5)
        #expect(loading.secondaryAction == .cancel)

        let ready: ModelActionState = ModelActionState.ready
        #expect(ready.secondaryAction == .delete)

        let error: ModelActionState = ModelActionState.error("Error")
        #expect(error.secondaryAction == .cancel)
    }

    @Test("isActive computed property")
    func testIsActive() {
        let available: ModelActionState = ModelActionState.available
        #expect(available.isActive == false)

        let downloading: ModelActionState = ModelActionState.downloading(progress: 0.5)
        #expect(downloading.isActive == true)

        let paused: ModelActionState = ModelActionState.paused(progress: 0.5)
        #expect(paused.isActive == false)

        let loading: ModelActionState = ModelActionState.loading(progress: 0.5)
        #expect(loading.isActive == true)

        let ready: ModelActionState = ModelActionState.ready
        #expect(ready.isActive == false)

        let error: ModelActionState = ModelActionState.error("Error")
        #expect(error.isActive == false)
    }

    @Test("actionLabel computed property")
    func testActionLabel() {
        let available: ModelActionState = ModelActionState.available
        #expect(available.actionLabel == "Download")

        let downloading: ModelActionState = ModelActionState.downloading(progress: 0.5)
        #expect(downloading.actionLabel == "Downloading 50%")

        let paused: ModelActionState = ModelActionState.paused(progress: 0.5)
        #expect(paused.actionLabel == "Paused 50%")

        let loading: ModelActionState = ModelActionState.loading(progress: 0.8)
        #expect(loading.actionLabel == "Loading 80%")

        let ready: ModelActionState = ModelActionState.ready
        #expect(ready.actionLabel == "Ready")

        let error: ModelActionState = ModelActionState.error("Network error")
        #expect(error.actionLabel == "Error")
    }

    @Test("Valid state transitions")
    func testValidTransitions() {
        // available -> downloading
        #expect(ModelActionState.isValidTransition(from: .available, to: .downloading(progress: 0)))

        // downloading -> paused
        #expect(ModelActionState.isValidTransition(from: .downloading(progress: 0.5), to: .paused(progress: 0.5)))

        // paused -> downloading
        #expect(ModelActionState.isValidTransition(from: .paused(progress: 0.5), to: .downloading(progress: 0.5)))

        // downloading -> loading
        #expect(ModelActionState.isValidTransition(from: .downloading(progress: 1.0), to: .loading(progress: 0)))

        // loading -> ready
        #expect(ModelActionState.isValidTransition(from: .loading(progress: 1.0), to: .ready))

        // any -> error
        #expect(ModelActionState.isValidTransition(from: .available, to: .error("Error")))
        #expect(ModelActionState.isValidTransition(from: .downloading(progress: 0.5), to: .error("Error")))
        #expect(ModelActionState.isValidTransition(from: .ready, to: .error("Error")))
    }

    @Test("State from DownloadStatus and ModelAvailability")
    func testStateFromComponents() {
        // Not downloaded, not ready
        let available: ModelActionState = ModelActionState.from(download: .notStarted, availability: .notReady)
        #expect(available == .available)

        // Downloading
        let downloading: ModelActionState = ModelActionState.from(
            download: .downloading(progress: 0.5),
            availability: .notReady
        )
        if case .downloading(let progress) = downloading {
            #expect(progress == 0.5)
        } else {
            Issue.record("Expected downloading state")
        }

        // Paused
        let paused: ModelActionState = ModelActionState.from(download: .paused(progress: 0.5), availability: .notReady)
        if case .paused(let progress) = paused {
            #expect(progress == 0.5)
        } else {
            Issue.record("Expected paused state")
        }

        // Downloaded but loading
        let loading: ModelActionState = ModelActionState.from(
            download: .completed,
            availability: .loading(progress: 0.3)
        )
        if case .loading(let progress) = loading {
            #expect(progress == 0.3)
        } else {
            Issue.record("Expected loading state")
        }

        // Ready
        let ready: ModelActionState = ModelActionState.from(download: .completed, availability: .ready)
        #expect(ready == .ready)

        // Download error
        let downloadError: ModelActionState = ModelActionState.from(
            download: .failed(error: "Network error"),
            availability: .notReady
        )
        if case .error(let message) = downloadError {
            #expect(message == "Network error")
        } else {
            Issue.record("Expected error state")
        }

        // Availability error
        let availabilityError: ModelActionState = ModelActionState.from(
            download: .completed,
            availability: .error("Load failed")
        )
        if case .error(let message) = availabilityError {
            #expect(message == "Load failed")
        } else {
            Issue.record("Expected error state")
        }
    }

    @Test("Equatable conformance")
    func testEquatable() {
        let downloading1: ModelActionState = ModelActionState.downloading(progress: 0.5)
        let downloading2: ModelActionState = ModelActionState.downloading(progress: 0.5)
        let downloading3: ModelActionState = ModelActionState.downloading(progress: 0.6)

        #expect(downloading1 == downloading2)
        #expect(downloading1 != downloading3)

        let error1: ModelActionState = ModelActionState.error("Error A")
        let error2: ModelActionState = ModelActionState.error("Error A")
        let error3: ModelActionState = ModelActionState.error("Error B")

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test("Codable conformance")
    func testCodable() throws {
        let testCases: [ModelActionState] = [
            .available,
            .downloading(progress: 0.5),
            .paused(progress: 0.7),
            .loading(progress: 0.3),
            .ready,
            .error("Test error")
        ]

        for original in testCases {
            let encoder: JSONEncoder = JSONEncoder()
            let data: Data = try encoder.encode(original)

            let decoder: JSONDecoder = JSONDecoder()
            let decoded: ModelActionState = try decoder.decode(ModelActionState.self, from: data)

            #expect(decoded == original)
        }
    }
}
