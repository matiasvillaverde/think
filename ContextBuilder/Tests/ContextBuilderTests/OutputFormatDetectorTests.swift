@testable import ContextBuilder
import Foundation
import Testing

@Suite("Output Format Detector Tests")
internal struct OutputFormatDetectorTests {
    @Test("Detects Harmony format")
    func testDetectHarmony() {
        let output = "<|channel|>analysis<|message|>test<|return|>"
        #expect(OutputFormatDetector.detect(from: output) == .harmony)
    }

    @Test("Detects Kimi format")
    func testDetectKimi() {
        let output = "<|tool_calls_section_begin|><|tool_call_begin|>"
        #expect(OutputFormatDetector.detect(from: output) == .kimi)
    }

    @Test("Detects ChatML format")
    func testDetectChatML() {
        let output = "<commentary>test</commentary>"
        #expect(OutputFormatDetector.detect(from: output) == .chatml)
    }

    @Test("Returns unknown for plain text")
    func testDetectUnknown() {
        let output = "Just plain text."
        #expect(OutputFormatDetector.detect(from: output) == .unknown)
    }
}
