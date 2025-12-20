@testable import AudioGenerator
import AVFoundation
import Foundation
import Testing

extension AudioGenerationTests {
    @Test("Resources not initialized on AudioEngine creation")
    func testResourcesNotInitializedOnCreation() async throws {
        // Given/When
        let engine: AudioEngine = AudioEngine()

        // Then
        // We need a way to verify resources aren't initialized
        // This will require exposing a method or property to check initialization state
        let isInitialized: Bool = await engine.isInitialized()
        #expect(!isInitialized)
    }

    @Test("Empty text doesn't trigger initialization")
    func testEmptyTextDoesNotInitialize() async throws {
        // Given
        let engine: AudioEngine = AudioEngine()

        // When
        await engine.say("")

        // Then
        let isInitialized: Bool = await engine.isInitialized()
        #expect(!isInitialized)
    }
}
