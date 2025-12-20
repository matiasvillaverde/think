import Abstractions
@preconcurrency import AVFoundation
import MLX
import NaturalLanguage
import OSLog
import SwiftUI

public actor AudioEngine: AudioGenerating {
    // MARK: - Logging
    private static let logger: Logger = Logger(subsystem: "AudioGenerator", category: "AudioEngine")

    // MARK: - Audio Resources
    private struct AudioResources: @unchecked Sendable {
        let kokoroTTSEngine: KokoroTTS
        let audioEngine: AVAudioEngine
        let playerNode: AVAudioPlayerNode

        init() throws {
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

    // MARK: - Initialization
    public init() {
        // Lazy initialization - resources created on first use
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

            do {
                let resources: AudioResources = try AudioResources()

                // Cache the loaded resources and clear the loading task
                self.audioResources = resources
                self.initializationTask = nil

                Self.logger.notice("Lazy initialization completed successfully")
                return resources
            } catch {
                Self.logger.error("Failed to initialize audio resources: \(error.localizedDescription, privacy: .public)")
                self.initializationTask = nil
                throw error
            }
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

        // Initialize resources if needed
        guard let resources = try? await ensureInitialized() else {
            Self.logger.error("Failed to initialize audio resources for TTS")
            return
        }

        // Create a queue to manage audios that need to be played
        let audioQueue: AsyncQueue = AsyncQueue()

        // Create a task completion tracker
        await audioQueue.setTotalItems(sentences.count)

        // Start a background task to generate all audio
        Task.detached {
            Self.logger.info("Starting background audio generation for \(sentences.count) sentences")
            for (index, sentence) in sentences.enumerated() {
                Self.logger.debug("Generating audio for sentence \(index + 1)/\(sentences.count)")
                // Generate audio for each sentence
                let audio: [Float] = await self.generateAudio(text: sentence, resources: resources)
                // Add it to the queue
                await audioQueue.enqueue(audio)
            }
            // Mark that all sentences have been processed
            await audioQueue.markAsComplete()
            Self.logger.info("Background audio generation completed")
        }

        #if os(iOS)
        activateAudioSession()
        #endif

        // Start playback process in the main task
        Self.logger.info("Starting audio playback")
        var playedCount: Int = 0
        while let audio = await audioQueue.dequeueUntilComplete() {
            playedCount += 1
            Self.logger.debug("Playing audio segment \(playedCount)")
            // Play each audio and wait until it completes before moving to the next
            await playAudioBufferAndWait(audio: audio, resources: resources)
        }
        Self.logger.notice("Text-to-speech completed successfully")

        #if os(iOS)
        deactivateAudioSession()
        #endif
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
        guard let resources = try? await ensureInitialized() else {
            Self.logger.error("Failed to initialize resources for test audio generation")
            return []
        }
        return generateAudio(text: text, resources: resources)
    }

    // Simple async queue implementation
    private actor AsyncQueue {
        private var items: [[Float]] = []
        private var dequeueTasks: [CheckedContinuation<[Float]?, Never>] = []
        private var isComplete: Bool = false
        private var processedItems: Int = 0
        private var totalItems: Int = 0

        func setTotalItems(_ count: Int) {
            totalItems = count
        }

        func markAsComplete() {
            isComplete = true
            // Resume any waiting dequeue tasks with nil if the queue is empty
            if items.isEmpty {
                for continuation in dequeueTasks {
                    continuation.resume(returning: nil)
                }
                dequeueTasks.removeAll()
            }
        }

        func enqueue(_ item: [Float]) {
            if let continuation: CheckedContinuation<[Float]?, Never> = dequeueTasks.first {
                dequeueTasks.removeFirst()
                continuation.resume(returning: item)
            } else {
                items.append(item)
            }
        }

        func dequeue() async -> [Float]? {
            if let item: [Float] = items.first {
                items.removeFirst()
                processedItems += 1
                return item
            }
            return await withCheckedContinuation { continuation in
                dequeueTasks.append(continuation)
            }
        }

        // New method that waits until complete if queue is empty
        func dequeueUntilComplete() async -> [Float]? {
            if let item: [Float] = items.first {
                items.removeFirst()
                processedItems += 1
                return item
            }
            if isComplete,
                processedItems >= totalItems {
                // All items have been processed and played
                return nil
            }
            // Wait for more items or completion
            return await withCheckedContinuation { continuation in
                dequeueTasks.append(continuation)
            }
        }
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
