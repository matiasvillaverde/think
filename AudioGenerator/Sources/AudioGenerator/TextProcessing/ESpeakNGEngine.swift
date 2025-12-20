import ESpeakNG
import Foundation
import OSLog

// swiftlint:disable force_unwrapping

// ESpeakNG wrapper for phonemizing the text strings
internal final class ESpeakNGEngine {
    // MARK: - Logging
    private static let logger: Logger = Logger(subsystem: "AudioGenerator", category: "ESpeakNGEngine")

    private var language: LanguageDialect = .unspecified
    private var languageMapping: [String: String] = [:]

    enum ESpeakNGEngineError: Error {
        case dataBundleNotFound
        case couldNotInitialize
        case languageNotFound
        case internalError
        case languageNotSet
        case couldNotPhonemize
    }

    // Available languages
    enum LanguageDialect: String, CaseIterable {
        case unspecified = ""
        case enUS = "en-us"
        case enGB = "en-gb"
    }

    // After constructing the wrapper, call setLanguage() before phonemizing any text
    init() throws {
        Self.logger.info("Initializing ESpeakNG engine")

        if let bundleURLStr = findDataBundlePath() {
            let initOK: Int32 = espeak_Initialize(AUDIO_OUTPUT_PLAYBACK, 0, bundleURLStr, 0)

            if initOK != Constants.successAudioSampleRate {
                Self.logger.error("ESpeakNG initialization failed")
                throw ESpeakNGEngineError.couldNotInitialize
            }

            var languageList: Set<String> = []
            let voiceList: UnsafeMutablePointer<UnsafePointer<espeak_VOICE>?>? = espeak_ListVoices(nil)
            var index: Int = 0
            while let voicePointer = voiceList?.advanced(by: index).pointee {
                let voice: espeak_VOICE = voicePointer.pointee
                if let cLang = voice.languages {
                    let language: String = String(cString: cLang, encoding: .utf8)!
                        .replacingOccurrences(of: "\u{05}", with: "")
                        .replacingOccurrences(of: "\u{02}", with: "")
                    languageList.insert(language)

                    if let cName = voice.identifier {
                        let name: String = String(cString: cName, encoding: .utf8)!
                            .replacingOccurrences(of: "\u{05}", with: "")
                            .replacingOccurrences(of: "\u{02}", with: "")
                        languageMapping[language] = name
                    }
                }

                index += 1
            }

            try LanguageDialect.allCases.forEach { dialect in
                if !dialect.rawValue.isEmpty, !languageList.contains(dialect.rawValue) {
                    Self.logger.error("Language dialect \(String(describing: dialect)) not found in voice list")
                    throw ESpeakNGEngineError.languageNotFound
                }
            }

            Self.logger.notice("ESpeakNG engine initialized with \(languageList.count) languages")
        } else {
            Self.logger.error("ESpeakNG data bundle not found")
            throw ESpeakNGEngineError.dataBundleNotFound
        }
    }

    // Destructor
    deinit {
        let terminateOK: espeak_ERROR = espeak_Terminate()
        Self.logger.info("ESpeakNG engine terminated: \(terminateOK == EE_OK)")
    }

    // Sets the language that will be used for phonemizing
    // If the function returns without throwing an exception then consider new language set!
    func setLanguage(for voice: TTSVoice) throws {
        Self.logger.info("Setting language for voice: \(String(describing: voice))")

        guard let language = Constants.voice2Language[voice],
            let name = languageMapping[language.rawValue]
        else {
            Self.logger.error("Language mapping not found for voice: \(String(describing: voice))")
            throw ESpeakNGEngineError.languageNotFound
        }

        let result: espeak_ERROR = name.withCString { espeak_SetVoiceByName($0) }

        if result == EE_NOT_FOUND {
            Self.logger.error("Voice not found: \(name)")
            throw ESpeakNGEngineError.languageNotFound
        }
        if result != EE_OK {
            Self.logger.error("Failed to set voice: \(name)")
            throw ESpeakNGEngineError.internalError
        }

        self.language = language
        Self.logger.notice("Language set to: \(language.rawValue)")
    }

    // Phonemizes the text string that can then be passed to the next stage
    func phonemize(text: String) throws -> String {
        guard language != .unspecified else {
            Self.logger.error("Language not set before phonemization")
            throw ESpeakNGEngineError.languageNotSet
        }

        guard !text.isEmpty else {
            Self.logger.debug("Empty text provided for phonemization")
            return ""
        }

        Self.logger.debug("Phonemizing text: \(text.count) characters")

        let textCString: [CChar] = Array(text.utf8CString)
        let phonemesMode: Int32 = Int32((Int32(Character("_").asciiValue!) << 8) | 0x02)
        let result: [String] = textCString.withUnsafeBytes { bytes in
            var textPtr: UnsafeRawPointer? = bytes.baseAddress
            return withUnsafeMutablePointer(to: &textPtr) { ptr in
            var resultWords: [String] = []
            while ptr.pointee != nil {
                let result: UnsafePointer<CChar>? = ESpeakNG.espeak_TextToPhonemes(ptr, espeakCHARS_UTF8, phonemesMode)
                if let result {
                    resultWords.append(String(cString: result, encoding: .utf8)!)
                }
            }
            return resultWords
            }
        }

        if !result.isEmpty {
            let phonemes: String = postProcessPhonemes(result.joined(separator: " "))
            Self.logger.debug("Phonemization completed: \(phonemes.count) characters")
            return phonemes
        }
        Self.logger.error("Phonemization failed for text")
        throw ESpeakNGEngineError.couldNotPhonemize
    }

    // Post processes manually phonemes before returning them
    // NOTE: This is currently only for English, handling other langauges requires different kind of postproccessing
    private func postProcessPhonemes(_ phonemes: String) -> String {
        var result: String = phonemes.trimmingCharacters(in: .whitespacesAndNewlines)
        for (old, new) in Constants.E2M {
            result = result.replacingOccurrences(of: old, with: new)
        }

        result = result.replacingOccurrences(of: "(\\S)\u{0329}", with: "ᵊ$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "\u{0329}", with: "")

        if language == .enGB {
            result = result.replacingOccurrences(of: "e^ə", with: "ɛː")
            result = result.replacingOccurrences(of: "iə", with: "ɪə")
            result = result.replacingOccurrences(of: "ə^ʊ", with: "Q")
        } else {
            result = result.replacingOccurrences(of: "o^ʊ", with: "O")
            result = result.replacingOccurrences(of: "ɜːɹ", with: "ɜɹ")
            result = result.replacingOccurrences(of: "ɜː", with: "ɜɹ")
            result = result.replacingOccurrences(of: "ɪə", with: "iə")
            result = result.replacingOccurrences(of: "ː", with: "")
        }

        // For espeak < 1.52
        result = result.replacingOccurrences(of: "o", with: "ɔ")
        return result.replacingOccurrences(of: "^", with: "")
    }

    // Find the data bundle that is inside the framework
    private func findDataBundlePath() -> String? {
        if let frameworkBundle = Bundle(identifier: "com.kokoro.espeakng"),
            let dataBundleURL = frameworkBundle.url(forResource: "espeak-ng-data", withExtension: "bundle") {
            return dataBundleURL.path
        }
        return nil
    }

    private enum Constants {
        static let successAudioSampleRate: Int32 = 22_050
        static let E2M: [(String, String)] = [
            ("ʔˌn\u{0329}", "tn"), ("ʔn\u{0329}", "tn"), ("ʔn", "tn"), ("ʔ", "t"),
            ("a^ɪ", "I"), ("a^ʊ", "W"),
            ("d^ʒ", "ʤ"),
            ("e^ɪ", "A"), ("e", "A"),
            ("t^ʃ", "ʧ"),
            ("ɔ^ɪ", "Y"),
            ("ə^l", "ᵊl"),
            ("ʲo", "jo"), ("ʲə", "jə"), ("ʲ", ""),
            ("ɚ", "əɹ"),
            ("r", "ɹ"),
            ("x", "k"), ("ç", "k"),
            ("ɐ", "ə"),
            ("ɬ", "l"),
            ("\u{0303}", "")
        ].sorted { $0.0.count > $1.0.count }
        nonisolated(unsafe) static let voice2Language: [TTSVoice: LanguageDialect] = [
            .afHeart: .enUS,
            .bmGeorge: .enGB,
            .zfXiaoni: .enGB
        ]
    }
}
// swiftlint:enable force_unwrapping
