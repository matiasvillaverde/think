import Abstractions
import AbstractionsTestUtilities
@testable import Database
import Foundation
import Testing
@testable import ViewModels

@Suite("AudioViewModel Talk Mode Tests")
internal struct AudioViewModelTests {
    @Test("Wake word in same utterance triggers generation")
    @MainActor
    func wakeWordTriggersGeneration() async throws {
        let database: Database = try await Self.makeDatabase()
        let speech: MockSpeechRecognizer = MockSpeechRecognizer(
            transcripts: ["hey think turn on the lights"]
        )
        let audio: MockAudioGenerator = MockAudioGenerator()
        let generator: MockGenerator = MockGenerator()

        let viewModel: AudioViewModel = AudioViewModel(
            audio: audio,
            speech: speech,
            database: database
        )
        await viewModel.setWakeWordEnabled(true)
        await viewModel.updateWakePhrase("hey think")

        await viewModel.startTalkMode(generator: generator)
        try await Task.sleep(nanoseconds: 150_000_000)
        await viewModel.stopTalkMode()

        let prompts: [String] = await generator.prompts
        #expect(prompts == ["turn on the lights"])
    }

    @Test("Wake word followed by command triggers follow-up")
    @MainActor
    func wakeWordThenFollowUpTriggersGeneration() async throws {
        let database: Database = try await Self.makeDatabase()
        let speech: MockSpeechRecognizer = MockSpeechRecognizer(
            transcripts: ["hey think", "tell me a joke"]
        )
        let audio: MockAudioGenerator = MockAudioGenerator()
        let generator: MockGenerator = MockGenerator()

        let viewModel: AudioViewModel = AudioViewModel(
            audio: audio,
            speech: speech,
            database: database
        )
        await viewModel.setWakeWordEnabled(true)
        await viewModel.updateWakePhrase("hey think")

        await viewModel.startTalkMode(generator: generator)
        try await Task.sleep(nanoseconds: 200_000_000)
        await viewModel.stopTalkMode()

        let prompts: [String] = await generator.prompts
        #expect(prompts == ["tell me a joke"])
    }

    @Test("Wake word disabled sends raw transcript")
    @MainActor
    func wakeWordDisabledSendsTranscript() async throws {
        let database: Database = try await Self.makeDatabase()
        let speech: MockSpeechRecognizer = MockSpeechRecognizer(
            transcripts: ["tell me the weather"]
        )
        let audio: MockAudioGenerator = MockAudioGenerator()
        let generator: MockGenerator = MockGenerator()

        let viewModel: AudioViewModel = AudioViewModel(
            audio: audio,
            speech: speech,
            database: database
        )
        await viewModel.setWakeWordEnabled(false)

        await viewModel.startTalkMode(generator: generator)
        try await Task.sleep(nanoseconds: 150_000_000)
        await viewModel.stopTalkMode()

        let prompts: [String] = await generator.prompts
        #expect(prompts == ["tell me the weather"])
    }

    private static func makeDatabase() async throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database: Database = try Database.new(configuration: config)
        _ = try await database.execute(AppCommands.Initialize())
        return database
    }
}

// MARK: - Mocks

private enum MockSpeechError: Error {
    case noTranscript
}

private actor MockSpeechRecognizer: SpeechRecognizing {
    private var transcripts: [String]

    init(transcripts: [String]) {
        self.transcripts = transcripts
    }

    func startListening() async throws -> String {
        await Task.yield()
        guard !transcripts.isEmpty else {
            throw MockSpeechError.noTranscript
        }
        return transcripts.removeFirst()
    }

    func stopListening() async -> String {
        await Task.yield()
        return ""
    }
}

private actor MockAudioGenerator: AudioGenerating {
    private(set) var spoken: [String] = []

    func say(_ text: String) async {
        await Task.yield()
        spoken.append(text)
    }

    func hear() -> String? {
        nil
    }
}

private actor MockGenerator: ViewModelGenerating {
    private(set) var prompts: [String] = []

    func load(chatId: UUID) async { await Task.yield() }
    func unload() async { await Task.yield() }
    func generate(prompt: String, overrideAction: Action?) async {
        await Task.yield()
        prompts.append(prompt)
    }
    func stop() async { await Task.yield() }
    func modify(chatId: UUID, modelId: UUID) async { await Task.yield() }
}
