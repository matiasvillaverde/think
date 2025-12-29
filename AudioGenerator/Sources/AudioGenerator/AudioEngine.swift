import Abstractions
@preconcurrency import AVFoundation
import MLX
import NaturalLanguage
import OSLog
import SwiftUI

public actor AudioEngine: AudioGenerating {
    typealias PlaybackHandler = @Sendable ([Float]) async -> Void
    typealias AudioGenerator = @Sendable (String) async -> [Float]

    // MARK: - Logging
    private static let logger: Logger = Logger(subsystem: "AudioGenerator", category: "AudioEngine")

    // MARK: - Audio Resources
    private struct AudioResources: @unchecked Sendable {
        let kokoroTTSEngine: KokoroTTS
        let audioEngine: AVAudioEngine
        let playerNode: AVAudioPlayerNode

        init() {
            AudioEngine.logger.info("Initializing audio resources")
            kokoroTTSEngine = KokoroTTS()
            audioEngine = AVAudioEngine()
            playerNode = AVAudioPlayerNode()
            audioEngine.attach(playerNode)
            AudioEngine.logger.notice("Audio resources initialized successfully")
        }
    }

    // MARK: - Properties
    private var audioResources: AudioResources?
    private var initializationTask: Task<AudioResources, Error>?
    private var initializationCount: Int = 0
    private let playbackHandler: PlaybackHandler?
    private let audioGenerator: AudioGenerator?

    // MARK: - Initialization
    public init() {
        self.playbackHandler = nil
        self.audioGenerator = nil
        // Lazy initialization - resources created on first use
    }

    // Internal initializer for injecting handlers (testing)
    internal init(
        playbackHandler: @escaping PlaybackHandler,
        audioGenerator: AudioGenerator? = nil
    ) {
        self.playbackHandler = playbackHandler
        self.audioGenerator = audioGenerator
    }

    internal init(audioGenerator: @escaping AudioGenerator) {
        self.playbackHandler = nil
        self.audioGenerator = audioGenerator
    }

    // MARK: - Lazy Initialization
    private func ensureInitialized() async throws -> AudioResources {
        // If resources are already loaded, return them
        if let resources = audioResources {
            return resources
        }

        // If there's already a loading task in progress, wait for it
        if let loadingTask = initializationTask {
            return try await loadingTask.value
        }

        // Create new initialization task
        let loadingTask: Task<AudioResources, Error> = Task<AudioResources, Error> {
            Self.logger.info("Starting lazy initialization of audio resources")
            initializationCount += 1

            let resources: AudioResources = AudioResources()

            // Cache the loaded resources and clear the loading task
            self.audioResources = resources
            self.initializationTask = nil

            Self.logger.notice("Lazy initialization completed successfully")
            return resources
        }

        self.initializationTask = loadingTask
        return try await loadingTask.value
    }

    // MARK: - Audio Session Management
    #if os(iOS)
    private func activateAudioSession() {
        Self.logger.info("Activating iOS audio session")
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            Self.logger.notice("Audio session activated")
        } catch {
            Self.logger.error("Failed to activate audio session: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deactivateAudioSession() {
        Self.logger.info("Deactivating iOS audio session")
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
            Self.logger.notice("Audio session deactivated")
        } catch {
            Self.logger.error("Failed to deactivate audio session: \(error.localizedDescription, privacy: .public)")
        }
    }
    #endif

    // MARK: - Public Interface
    public func hear() -> String? {
        nil
    }

    public func say(_ text: String) async {
        Self.logger.info("Starting text-to-speech for \(text.count) characters")

        // Break text into sentences
        let sentences: [String] = breakTextIntoSentences(text)
        guard !sentences.isEmpty else {
            Self.logger.warning("No sentences found in text, skipping TTS")
            return
        }

        Self.logger.info("Processing \(sentences.count) sentences")

        if let playbackHandler, let audioGenerator {
            for sentence in sentences {
                let audio: [Float] = await audioGenerator(sentence)
                await playbackHandler(audio)
            }
            Self.logger.notice("Text-to-speech completed successfully")
            return
        }

        let needsResources: Bool = playbackHandler == nil || audioGenerator == nil
        let resources: AudioResources? = await resolveResourcesIfNeeded(needsResources: needsResources)
        if needsResources, resources == nil {
            return
        }

        // Create a queue to manage audios that need to be played
        let audioQueue: AudioEngineAsyncQueue = AudioEngineAsyncQueue()

        // Create a task completion tracker
        await audioQueue.setTotalItems(sentences.count)

        startBackgroundGeneration(sentences: sentences, resources: resources, queue: audioQueue)

        let shouldManageSession: Bool = playbackHandler == nil
        #if os(iOS)
        if shouldManageSession {
            activateAudioSession()
        }
        #endif

        await playAudioQueue(audioQueue, resources: resources)

        #if os(iOS)
        if shouldManageSession {
            deactivateAudioSession()
        }
        #endif
    }

    private func resolveResourcesIfNeeded(needsResources: Bool) async -> AudioResources? {
        guard needsResources else {
            return nil
        }
        guard let loadedResources = try? await ensureInitialized() else {
            Self.logger.error("Failed to initialize audio resources for TTS")
            return nil
        }
        return loadedResources
    }

    private func startBackgroundGeneration(
        sentences: [String],
        resources: AudioResources?,
        queue: AudioEngineAsyncQueue
    ) {
        Task.detached { [self] in
            Self.logger.info("Starting background audio generation for \(sentences.count) sentences")
            for (index, sentence) in sentences.enumerated() {
                Self.logger.debug("Generating audio for sentence \(index + 1)/\(sentences.count)")
                let audio: [Float] = await audioSamples(for: sentence, resources: resources)
                await queue.enqueue(audio)
            }
            await queue.markAsComplete()
            Self.logger.info("Background audio generation completed")
        }
    }

    private func audioSamples(for sentence: String, resources: AudioResources?) async -> [Float] {
        if let audioGenerator {
            return await audioGenerator(sentence)
        }
        guard let resources else {
            return []
        }
        return generateAudio(text: sentence, resources: resources)
    }

    private func playAudioQueue(_ queue: AudioEngineAsyncQueue, resources: AudioResources?) async {
        Self.logger.info("Starting audio playback")
        var playedCount: Int = 0
        while let audio = await queue.dequeueUntilComplete() {
            playedCount += 1
            Self.logger.debug("Playing audio segment \(playedCount)")
            if let playbackHandler {
                await playbackHandler(audio)
            } else if let resources {
                await playAudioBufferAndWait(audio: audio, resources: resources)
            }
        }
        Self.logger.notice("Text-to-speech completed successfully")
    }

    // Helper to make playing audio awaitable
    private func playAudioBufferAndWait(audio: [Float], resources: AudioResources) async {
        await withCheckedContinuation { continuation in
            guard let (format, buffer) = prepareAudioBuffer(audio: audio) else {
                continuation.resume()
                return
            }

            fillAudioBuffer(buffer: buffer, audio: audio)

            guard setupAudioEngine(resources: resources, format: format) else {
                continuation.resume()
                return
            }

            // Add completion handler to know when playback finished
            resources.playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts) {
                continuation.resume()
            }
            resources.playerNode.play()
        }
    }

    private func prepareAudioBuffer(audio: [Float]) -> (AVAudioFormat, AVAudioPCMBuffer)? {
        let sampleRate: Double = Double(KokoroTTS.Constants.samplingRate)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            Self.logger.error("Failed to create audio format")
            return nil
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(audio.count)
        ) else {
            Self.logger.error("Failed to create PCM buffer for \(audio.count) samples")
            return nil
        }

        buffer.frameLength = buffer.frameCapacity
        return (format, buffer)
    }

    private func fillAudioBuffer(buffer: AVAudioPCMBuffer, audio: [Float]) {
        guard let channels = buffer.floatChannelData else {
            Self.logger.error("Failed to get buffer channels")
            return
        }
        for i in 0 ..< audio.count {
            channels[0][i] = audio[i]
        }
    }

    private func setupAudioEngine(resources: AudioResources, format: AVAudioFormat) -> Bool {
        resources.audioEngine.connect(resources.playerNode, to: resources.audioEngine.mainMixerNode, format: format)
        do {
            try resources.audioEngine.start()
            return true
        } catch {
            Self.logger.error("Audio engine failed to start: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // Make generateAudio async to match the actor context
    private func generateAudio(text: String, resources: AudioResources) -> [Float] {
        do {
            let audioBuffer: MLXArray = try resources.kokoroTTSEngine.generateAudio(
                voice: .afHeart,
                text: text
            )
            let audioArray: [Float] = audioBuffer[0].asArray(Float.self)
            Self.logger.debug("Generated \(audioArray.count) audio samples")
            return audioArray
        } catch {
            Self.logger.error("Failed to generate audio: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // Expose generateAudio with backward compatibility for tests
    internal func generateAudio(text: String) async -> [Float] {
        if let audioGenerator {
            return await audioGenerator(text)
        }
        guard let resources = try? await ensureInitialized() else {
            Self.logger.error("Failed to initialize resources for test audio generation")
            return []
        }
        return generateAudio(text: text, resources: resources)
    }

    internal func breakTextIntoSentences(_ text: String) -> [String] {
        let tokenizer: NLTokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let sentence: String = String(text[tokenRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }

        return sentences
    }

    private func playAudioBuffer(audio _: [Float]) {
        // This method is no longer used but kept for reference
        logPrint("playAudioBuffer is deprecated - use playAudioBufferAndWait instead")
    }

    // MARK: - Testing Support
    internal func isInitialized() -> Bool {
        audioResources != nil
    }

    internal func getInitializationCount() -> Int {
        initializationCount
    }
}
