import Foundation
@testable import ModelDownloader
import Testing

@Suite("ModelAvailability Tests")
struct ModelAvailabilityTests {
    @Test("Initial availability is notReady")
    func testInitialAvailability() {
        let availability: ModelAvailability = ModelAvailability()
        #expect(availability == .notReady)
    }

    @Test("Availability transitions through loading")
    func testLoadingTransition() {
        var availability: ModelAvailability = ModelAvailability()
        availability = .loading(progress: 0.0)

        if case .loading(let progress) = availability {
            #expect(progress == 0.0)
        } else {
            Issue.record("Expected loading status")
        }

        availability = .loading(progress: 0.5)
        if case .loading(let progress) = availability {
            #expect(progress == 0.5)
        }
    }

    @Test("Availability transitions to ready")
    func testReadyTransition() {
        var availability: ModelAvailability = ModelAvailability()
        availability = .loading(progress: 1.0)
        availability = .ready

        #expect(availability == .ready)
    }

    @Test("Availability transitions to generating")
    func testGeneratingTransition() {
        var availability: ModelAvailability = ModelAvailability()
        availability = .ready
        availability = .generating

        #expect(availability == .generating)
    }

    @Test("Availability can transition to error")
    func testErrorTransition() {
        var availability: ModelAvailability = ModelAvailability()
        availability = .loading(progress: 0.5)
        availability = .error("Failed to load model")

        if case .error(let message) = availability {
            #expect(message == "Failed to load model")
        } else {
            Issue.record("Expected error status")
        }
    }

    @Test("isReady computed property")
    func testIsReady() {
        let notReady: ModelAvailability = ModelAvailability()
        #expect(notReady.isReady == false)

        let loading: ModelAvailability = ModelAvailability.loading(progress: 0.5)
        #expect(loading.isReady == false)

        let ready: ModelAvailability = ModelAvailability.ready
        #expect(ready.isReady == true)

        let generating: ModelAvailability = ModelAvailability.generating
        #expect(generating.isReady == true) // Still ready while generating

        let error: ModelAvailability = ModelAvailability.error("Error")
        #expect(error.isReady == false)
    }

    @Test("isLoading computed property")
    func testIsLoading() {
        let notReady: ModelAvailability = ModelAvailability()
        #expect(notReady.isLoading == false)

        let loading: ModelAvailability = ModelAvailability.loading(progress: 0.5)
        #expect(loading.isLoading == true)

        let ready: ModelAvailability = ModelAvailability.ready
        #expect(ready.isLoading == false)
    }

    @Test("isGenerating computed property")
    func testIsGenerating() {
        let notReady: ModelAvailability = ModelAvailability()
        #expect(notReady.isGenerating == false)

        let ready: ModelAvailability = ModelAvailability.ready
        #expect(ready.isGenerating == false)

        let generating: ModelAvailability = ModelAvailability.generating
        #expect(generating.isGenerating == true)
    }

    @Test("hasError computed property")
    func testHasError() {
        let notReady: ModelAvailability = ModelAvailability()
        #expect(notReady.hasError == false)

        let ready: ModelAvailability = ModelAvailability.ready
        #expect(ready.hasError == false)

        let error: ModelAvailability = ModelAvailability.error("Test error")
        #expect(error.hasError == true)
    }

    @Test("Equatable conformance")
    func testEquatable() {
        let loading1: ModelAvailability = ModelAvailability.loading(progress: 0.5)
        let loading2: ModelAvailability = ModelAvailability.loading(progress: 0.5)
        let loading3: ModelAvailability = ModelAvailability.loading(progress: 0.6)

        #expect(loading1 == loading2)
        #expect(loading1 != loading3)

        let error1: ModelAvailability = ModelAvailability.error("Error A")
        let error2: ModelAvailability = ModelAvailability.error("Error A")
        let error3: ModelAvailability = ModelAvailability.error("Error B")

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test("Codable conformance")
    func testCodable() throws {
        let testCases: [ModelAvailability] = [
            .notReady,
            .loading(progress: 0.5),
            .ready,
            .generating,
            .error("Test error message")
        ]

        for original: ModelAvailability in testCases {
            let encoder: JSONEncoder = JSONEncoder()
            let data: Data = try encoder.encode(original)

            let decoder: JSONDecoder = JSONDecoder()
            let decoded: ModelAvailability = try decoder.decode(ModelAvailability.self, from: data)

            #expect(decoded == original)
        }
    }
}
