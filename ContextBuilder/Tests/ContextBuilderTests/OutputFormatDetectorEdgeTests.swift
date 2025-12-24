@testable import ContextBuilder
import Foundation
import Testing

@Suite("Output Format Detector Edge Tests")
internal struct OutputFormatDetectorEdgeTests {
    @Test("Prefers Harmony over ChatML when both signatures exist")
    func testDetectHarmonyPriority() {
        let output = [
            "<|channel|>analysis<|message|>x<|return|>",
            "<commentary>y</commentary>"
        ].joined()
        #expect(OutputFormatDetector.detect(from: output) == .harmony)
    }

    @Test("Detects Kimi even if ChatML tags also appear")
    func testDetectKimiPriority() {
        let output = [
            "<commentary>x</commentary>",
            "<|tool_calls_section_begin|>"
        ].joined()
        #expect(OutputFormatDetector.detect(from: output) == .kimi)
    }

    @Test("Ignores tags inside code blocks")
    func testNoFalsePositiveInCode() {
        let output = [
            "```",
            "<|channel|>analysis<|message|>x",
            "```"
        ].joined(separator: "\n")
        #expect(OutputFormatDetector.detect(from: output) == .unknown)
    }
}
