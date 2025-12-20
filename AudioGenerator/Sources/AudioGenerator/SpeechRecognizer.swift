import Abstractions
@preconcurrency import AVFoundation
import Foundation
import os.log
@preconcurrency import Speech

/// An actor that handles speech recognition and automatically detects when the user has finished speaking.
public final actor SpeechRecognizer: @unchecked Sendable, SpeechRecognizing {
    // MARK: - Types
    /// Represents the current state of the speech recognizer
    enum RecognizerState: String {
        case idle = "idle"
        case listening = "listening"
        case processing = "processing"

        var description: String { rawValue }
    }

    // MARK: - Private Properties

    /// Logger for diagnostic information
    let logger: Logger = Logger(
        subsystem: "AudioGenerator",
        category: "SpeechRecognition"
    )
    /// The locale to use for speech recognition
    private let locale: Locale
    /// Time interval (in seconds) of silence that indicates the user has finished speaking
    private let silenceThreshold: TimeInterval
    /// Minimum energy level to consider as actual speech vs background noise
    private let minimumSpeechLevel: Float
    /// The speech recognizer instance
    let speechRecognizer: SFSpeechRecognizer?

    /// Audio engine to capture sound
    var audioEngine: AVAudioEngine?

    /// Current recognition request
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    /// Current recognition task
    var recognitionTask: SFSpeechRecognitionTask?

    /// Timestamp of the last audio input
    var lastAudioTimestamp: Date = Date()

    /// Task for detecting silence
    var silenceTask: Task<Void, Never>?

    /// Continuation for async result
    private var continuation: CheckedContinuation<String, Error>?

    /// Current transcript from recognition
    var currentTranscript: String = ""

    /// Current state of the recognizer
    var state: RecognizerState = .idle {
        didSet {
            logger.debug("State changed: \(oldValue.description) -> \(self.state.description)")
        }
    }

    /// Flag to track if we've received any audio since starting recognition
    var hasReceivedAudio: Bool = false

    /// The current level meter value (audio energy)
    var currentAudioLevel: Float = 0

    /// Audio route change notification observer
    var routeChangeObserver: NSObjectProtocol?

    /// Audio session interruption observer
    var interruptionObserver: NSObjectProtocol?

    // MARK: - Initialization

    /// Initializes a new speech recognizer
    /// - Parameters:
    ///   - locale: The locale to use for speech recognition (default: current locale)
    ///   - silenceThreshold: Time in seconds of silence to detect end of speech (default: 1.5)
    ///   - minimumSpeechLevel: Minimum audio level to consider as speech (default: 0.1)
    public init(
        locale: Locale = .current,
        silenceThreshold: TimeInterval = 1,
        minimumSpeechLevel: Float = 0.05
    ) {
        self.locale = locale
        self.silenceThreshold = silenceThreshold
        self.minimumSpeechLevel = minimumSpeechLevel
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    // MARK: - Public Methods

    /// Starts listening to user speech and automatically detects when they finish speaking.
    /// - Returns: The transcribed text when the user has finished speaking
    /// - Throws: RecognizerError if permissions are not granted or recognition fails
    public func startListening() async throws -> String {
        logger.debug("startListening called")

        // Check if we're already listening
        if state != .idle {
            logger.notice("Attempted to start listening while already active (state: \(self.state.description))")
            // Stop any existing session first
            return await stopListening()
        }

        // Reset state completely
        resetState()

        // Check for permissions first
        try await checkPermissions()

        // Now we're ready to start listening
        state = .listening

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            do {
                try setupAudioSession()
                try setupRecognition()
                logger.debug("Recognition started successfully")
            } catch {
                logger.error("Failed to start recognition: \(error.localizedDescription)")
                self.continuation = nil
                state = .idle
                continuation.resume(throwing: error)
            }
        }
    }

    /// Stops listening and returns any transcribed text immediately.
    /// Unlike cancelListening, this returns whatever was transcribed.
    public func stopListening() async -> String {
        logger.debug("stopListening called")

        // If we have no continuation, just clean up
        if continuation == nil {
            cleanupResources()
            resetState()
            return currentTranscript
        }

        // Otherwise, use the continuation
        return await withCheckedContinuation { continuation in
            // Only return the transcript if we actually received some audio
            let result: String = hasReceivedAudio ? currentTranscript : ""

            // Clean up and reset
            cleanupResources()
            resetState()

            // Complete with current transcript
            continuation.resume(returning: result)
        }
    }

    // MARK: - Private Methods - Permissions and Setup

    /// Sets up the audio engine and speech recognition
    private func setupRecognition() throws {
        let engine: AVAudioEngine = AVAudioEngine()
        audioEngine = engine

        // Create recognition request
        let request: SFSpeechAudioBufferRecognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        // Enable audio level detection if available
        if #available(iOS 16.0, macOS 13.0, *) {
            request.addsPunctuation = true
        }

        recognitionRequest = request

        // Configure input node with tap
        let inputNode: AVAudioInputNode = engine.inputNode
        let recordingFormat: AVAudioFormat = inputNode.outputFormat(forBus: 0)

        // Create a handler that will safely bridge to our actor
        let bufferHandler: AudioBufferHandler = AudioBufferHandler(recognizer: self, request: request)

        // Install tap to get audio buffer - using nonisolated helper
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: recordingFormat) { buffer, _ in
            // This executes outside the actor's isolation domain
            bufferHandler.handleBuffer(buffer)
        }

        // Create recognition task
        guard let recognizer = speechRecognizer else {
            throw RecognizerError.recognizerUnavailable
        }

        // Create a handler that will safely bridge to our actor
        let resultHandler: RecognitionResultHandler = RecognitionResultHandler(recognizer: self)

        // Start engine
        engine.prepare()
        try engine.start()

        // Create the recognition task with our nonisolated handler
        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            // This executes outside the actor's isolation domain
            resultHandler.handleResult(result, error)
        }
    }

    // MARK: - Private Methods - Notifications and Interruptions

    /// Handles audio route changes (e.g., headphones connected/disconnected)
    private func handleAudioRouteChange() {
        logger.debug("Audio route changed")

        // If we're actively listening, restart the audio session
        if state == .listening || state == .processing {
            #if os(iOS) || os(tvOS) || os(watchOS)
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                logger.error("Failed to reactivate audio session after route change: \(error.localizedDescription)")
            }
            #endif
        }
    }

    // MARK: - Actor-Isolated Methods

    /// Process new audio buffer received (called from handler)
    nonisolated func audioBufferReceived(buffer: AVAudioPCMBuffer) {
        // Create a task to safely call back into the actor
        // AVAudioPCMBuffer is effectively immutable once created, so this is safe
        Task { @Sendable in await self.handleAudioReceived(buffer: buffer) }
    }

    /// Updates internal state when audio is received
    private func handleAudioReceived(buffer: AVAudioPCMBuffer) {
        // Only process audio if we're in listening state
        guard state == .listening || state == .processing else { return }

        // Calculate audio level
        let level: Float = calculateAudioLevel(from: buffer)
        currentAudioLevel = level

        // Only consider this actual audio if it's above the minimum level
        let isActualSpeech: Bool = level > minimumSpeechLevel

        if isActualSpeech {
            // Mark that we've received audio
            if !hasReceivedAudio {
                logger.debug("First audio received (level: \(level))")
                hasReceivedAudio = true
            }

            // Update last audio timestamp
            lastAudioTimestamp = Date()

            // Ensure we're in processing state now
            if state == .listening {
                state = .processing
            }

            // Start/restart silence detection
            startSilenceDetection()
        }
    }

    /// Process recognition result (called from handler)
    nonisolated func processRecognitionResult(transcription: String?, isFinal: Bool, error: Error?) {
        // Create a task to safely call back into the actor
        Task { await self.handleRecognitionResult(transcription: transcription, isFinal: isFinal, error: error) }
    }

    /// Updates internal state with recognition results
    private func handleRecognitionResult(transcription: String?, isFinal: Bool, error: Error?) {
        // Only process results if we're in the right state
        guard state == .listening || state == .processing else { return }

        if let error {
            // Handle error
            logger.error("Recognition error: \(error.localizedDescription)")
            completeWithError(RecognizerError.recognitionFailed(error))
            return
        }

        if let transcription {
            // Update transcript if we have new text
            if !transcription.isEmpty {
                // Debug log if significant change in transcript
                if transcription != currentTranscript {
                    logger.debug("New transcription: \"\(transcription)\"")
                }

                currentTranscript = transcription
                hasReceivedAudio = true
            }

            // If result is final, complete
            if isFinal {
                logger.debug("Final transcription received: \"\(transcription)\"")
                completeWithResult(currentTranscript)
            }
        }
    }

    /// Starts or restarts the silence detection timer
    private func startSilenceDetection() {
        // Cancel existing task
        silenceTask?.cancel()

        // Create a new silence detection task
        silenceTask = Task { [silenceThreshold = self.silenceThreshold] in
            do {
                // Wait for the silence threshold duration
                try await Task.sleep(nanoseconds: UInt64(silenceThreshold * 1_000_000_000))

                // Check if we're still in a processing state
                guard self.state == .processing else { return }

                // Check if enough time has passed since last audio input
                let silenceDuration: TimeInterval = Date().timeIntervalSince(self.lastAudioTimestamp)
                if silenceDuration >= silenceThreshold {
                    logger.debug("Silence detected for \(silenceDuration) seconds")

                    // If we have a transcript, consider speech finished due to silence
                    if !self.currentTranscript.isEmpty {
                        logger.debug("Completing with transcript due to silence")
                        self.completeWithResult(self.currentTranscript)
                    } else if self.hasReceivedAudio {
                        // We received audio but got no transcript
                        logger.notice("Received audio but no transcript")
                        self.completeWithError(RecognizerError.noSpeechDetected)
                    }
                    // Otherwise, keep listening - might be background noise
                }
            } catch {
                // Task was cancelled, which is expected behavior
                logger.debug("Silence detection task cancelled")
            }
        }
    }

    /// Completes the recognition with the provided transcript
    private func completeWithResult(_ transcript: String) {
        // Only proceed if we have a continuation and are in the right state
        guard let continuation, state != .idle else { return }

        logger.debug("Completing recognition with result: \"\(transcript)\"")

        // Store result and clear continuation
        let result: String = transcript
        self.continuation = nil

        // Clean up and reset state
        cleanupResources()
        resetState()

        // Complete with result
        continuation.resume(returning: result)
    }

    /// Completes the recognition with an error
    private func completeWithError(_ error: Error) {
        // Only proceed if we have a continuation and are in the right state
        guard let continuation, state != .idle else { return }

        logger.error("Completing recognition with error: \(error.localizedDescription)")

        // Clear continuation
        self.continuation = nil

        // Clean up and reset state
        cleanupResources()
        resetState()

        // Complete with error
        continuation.resume(throwing: error)
    }

    // MARK: - Utility Methods

    /// Calculates the audio level (energy) from an audio buffer
    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else {
            return 0.0
        }

        let channelDataValue: UnsafeMutablePointer<Float> = channelData.pointee
        let channelDataValueArray: [Float] = stride(
            from: 0,
            to: Int(buffer.frameLength),
            by: buffer.stride
        ).map { channelDataValue[$0] }

        // Calculate RMS (root mean square) as audio level
        return sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength)) as Float
    }
}
