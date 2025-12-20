// swiftlint:disable line_length
import Abstractions
import Foundation
import OSLog

public actor AudioViewModel: AudioViewModeling {
    private let audio: AudioGenerating
    private let speech: SpeechRecognizing
    private let logger: Logger = Logger(subsystem: "ViewModels", category: "AudioViewModel")

    public init(
        audio: AudioGenerating,
        speech: SpeechRecognizing
    ) {
        self.audio = audio
        self.speech = speech
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

    public func listen(generator: ViewModelGenerating) {
        Task {
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
    }

    public func stopListening() {
        Task {
            await speech.stopListening()
        }
    }
}
// swiftlint:enable line_length
