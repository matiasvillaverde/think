// swiftlint:disable line_length
import Abstractions
import Database
import Foundation
import OSLog

public actor AudioViewModel: AudioViewModeling {
    private let audio: AudioGenerating
    private let speech: SpeechRecognizing
    private let database: DatabaseProtocol
    private let logger: Logger = Logger(subsystem: "ViewModels", category: "AudioViewModel")

    private var talkModeTask: Task<Void, Never>?
    private var internalTalkModeState: TalkModeState = .idle
    private var internalWakePhrase: String = "hey think"
    private var internalWakeWordEnabled: Bool = true
    private var internalTalkModeEnabled: Bool = false

    public init(
        audio: AudioGenerating,
        speech: SpeechRecognizing,
        database: DatabaseProtocol
    ) {
        self.audio = audio
        self.speech = speech
        self.database = database

        Task { [weak self] in
            await self?.refreshSettings()
        }
    }

    public func cleanTextForSpeech(_ markdownText: String) -> String {
        var cleanedText: String = markdownText

        // Remove code blocks
        cleanedText = cleanedText.replacingOccurrences(of: "```[\\s\\S]*?```", with: "code block omitted", options: .regularExpression)

        // Remove inline code backticks but keep content
        cleanedText = cleanedText.replacingOccurrences(of: "`([^`]*)`", with: "$1", options: .regularExpression)

        // Remove header symbols while preserving content
        cleanedText = cleanedText.replacingOccurrences(of: "^#{1,6}\\s+(.+)$", with: "$1", options: .regularExpression)

        // Remove bold/italic markers while preserving content and punctuation
        cleanedText = cleanedText.replacingOccurrences(of: "\\*\\*([^*]*)\\*\\*", with: "$1", options: .regularExpression)
        cleanedText = cleanedText.replacingOccurrences(of: "\\*([^*]*)\\*", with: "$1", options: .regularExpression)
        cleanedText = cleanedText.replacingOccurrences(of: "__([^_]*)__", with: "$1", options: .regularExpression)
        cleanedText = cleanedText.replacingOccurrences(of: "_([^_]*)_", with: "$1", options: .regularExpression)

        // Convert bullet points to text while preserving content
        cleanedText = cleanedText.replacingOccurrences(of: "^\\s*[-*+]\\s+(.+)$", with: "$1", options: .regularExpression)

        // Convert numbered lists to text while preserving content
        cleanedText = cleanedText.replacingOccurrences(of: "^\\s*\\d+\\.\\s+(.+)$", with: "$1", options: .regularExpression)

        // Remove URLs but keep link text
        cleanedText = cleanedText.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)

        // Remove HTML tags
        cleanedText = cleanedText.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        return cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func say(_ text: String) {
        Task {
            let cleanedText: String = cleanTextForSpeech(text)
            await audio.say(cleanedText)
        }
    }

    public func listen(generator: ViewModelGenerating) async {
        do {
            let text: String = try await speech.startListening()
            await generator.generate(
                prompt: text,
                overrideAction: .textGeneration([])
            )
        } catch {
            logger.error("Failed to start listening: \(error.localizedDescription)")
        }
    }

    public func stopListening() {
        Task {
            _ = await speech.stopListening()
        }
    }

    public var talkModeState: TalkModeState { internalTalkModeState }
    public var wakePhrase: String { internalWakePhrase }
    public var isWakeWordEnabled: Bool { internalWakeWordEnabled }
    public var isTalkModeEnabled: Bool { internalTalkModeEnabled }

    public func startTalkMode(generator: ViewModelGenerating) async {
        internalTalkModeEnabled = true
        _ = try? await database.write(SettingsCommands.UpdateVoice(talkModeEnabled: .set(true)))
        await refreshSettings()

        talkModeTask?.cancel()
        talkModeTask = Task { [weak self] in
            guard let self else {
                return
            }
            await runTalkModeLoop(generator: generator)
        }
    }

    public func stopTalkMode() async {
        talkModeTask?.cancel()
        talkModeTask = nil
        internalTalkModeEnabled = false
        internalTalkModeState = .idle
        _ = try? await database.write(SettingsCommands.UpdateVoice(talkModeEnabled: .set(false)))
        _ = await speech.stopListening()
    }

    public func updateWakePhrase(_ phrase: String) async {
        let cleaned: String = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        internalWakePhrase = cleaned
        _ = try? await database.write(SettingsCommands.UpdateVoice(wakePhrase: .set(cleaned)))
    }

    public func setWakeWordEnabled(_ enabled: Bool) async {
        internalWakeWordEnabled = enabled
        _ = try? await database.write(SettingsCommands.UpdateVoice(wakeWordEnabled: .set(enabled)))
    }

    private func refreshSettings() async {
        do {
            let snapshot: AudioSettingsSnapshot = try await fetchSettingsSnapshot()
            internalTalkModeEnabled = snapshot.talkModeEnabled
            internalWakeWordEnabled = snapshot.wakeWordEnabled
            internalWakePhrase = snapshot.wakePhrase
        } catch {
            logger.error("Failed to refresh settings: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func fetchSettingsSnapshot() async throws -> AudioSettingsSnapshot {
        let settings: AppSettings = try await database.read(SettingsCommands.GetOrCreate())
        return AudioSettingsSnapshot(
            talkModeEnabled: settings.talkModeEnabled,
            wakeWordEnabled: settings.wakeWordEnabled,
            wakePhrase: settings.wakePhrase
        )
    }

    private func runTalkModeLoop(generator: ViewModelGenerating) async {
        while !Task.isCancelled {
            if internalWakeWordEnabled {
                internalTalkModeState = .waitingForWakeWord
            } else {
                internalTalkModeState = .listening
            }

            do {
                let transcript: String = try await speech.startListening()
                if Task.isCancelled { break }
                let cleaned: String = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.isEmpty {
                    continue
                }

                if internalWakeWordEnabled {
                    guard let command = extractCommand(from: cleaned) else {
                        continue
                    }
                    if command.isEmpty {
                        internalTalkModeState = .listening
                        let followUp: String = try await speech.startListening()
                        let followUpCleaned: String = followUp.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        if followUpCleaned.isEmpty {
                            continue
                        }
                        await processCommand(followUpCleaned, generator: generator)
                    } else {
                        await processCommand(command, generator: generator)
                    }
                } else {
                    await processCommand(cleaned, generator: generator)
                }
            } catch {
                logger.error("Talk mode listening failed: \(error.localizedDescription)")
                if Task.isCancelled {
                    break
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }

        internalTalkModeState = .idle
    }

    private func processCommand(_ command: String, generator: ViewModelGenerating) async {
        internalTalkModeState = .processing
        await generator.generate(
            prompt: command,
            overrideAction: .textGeneration([])
        )

        if internalWakeWordEnabled {
            internalTalkModeState = .waitingForWakeWord
        } else {
            internalTalkModeState = .listening
        }
    }

    private func extractCommand(from transcript: String) -> String? {
        let lowerTranscript: String = transcript.lowercased()
        let lowerWake: String = internalWakePhrase.lowercased()
        guard !lowerWake.isEmpty else {
            return transcript
        }

        guard let range = lowerTranscript.range(of: lowerWake) else {
            return nil
        }

        let distance: Int = lowerTranscript.distance(
            from: lowerTranscript.startIndex,
            to: range.upperBound
        )
        let startIndex: String.Index = transcript.index(
            transcript.startIndex,
            offsetBy: distance
        )
        let remainder: Substring = transcript[startIndex...]
        return remainder.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
// swiftlint:enable line_length

private struct AudioSettingsSnapshot: Sendable {
    let talkModeEnabled: Bool
    let wakeWordEnabled: Bool
    let wakePhrase: String
}
