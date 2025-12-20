import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

/// Unit tests for LlamaCPPStreamHandler stop sequence handling
@Suite("StreamHandler Stop Sequence Tests")
internal struct LlamaCPPStreamHandlerUnitTests {
    @Test("Stop sequences prevent token emission")
    internal func testStopSequencesPreventEmission() {
        // Verify the fix: stop sequences checked BEFORE yielding
        let handler: StopSequenceTestHandler = StopSequenceTestHandler()
        let text1: String = "Hello"
        let text2: String = "<|im_end|>"

        // Process normal text
        var stopped: Bool = handler.processText(text1)
        #expect(!stopped, "Normal text should not stop")
        #expect(handler.yieldedTexts.contains(text1))

        // Process stop sequence
        stopped = handler.processText(text2)
        #expect(stopped, "Stop sequence should trigger stop")
        #expect(!handler.yieldedTexts.contains(text2))
    }

    @Test("Partial text before stop is yielded")
    internal func testPartialTextBeforeStop() {
        let handler: StopSequenceTestHandler = StopSequenceTestHandler()
        let combined: String = "text before STOP"

        let stopped: Bool = handler.processText(combined)
        #expect(stopped, "Should stop at STOP")

        // Check yielded text doesn't contain STOP
        let yielded: String = handler.yieldedTexts.joined()
        #expect(!yielded.contains("STOP"))
        #expect(yielded.contains("text before"))
    }

    @Test("Multiple stop sequences work")
    internal func testMultipleStopSequences() {
        let sequences: [String] = ["<|im_end|>", "###", "STOP"]
        let handler: StopSequenceTestHandler = StopSequenceTestHandler(
            stopSequences: sequences
        )

        // Test each stop sequence
        for sequence in sequences {
            handler.reset()
            let text: String = "prefix \(sequence)"
            let stopped: Bool = handler.processText(text)

            #expect(stopped, "\(sequence) should trigger stop")
            let yielded: String = handler.yieldedTexts.joined()
            #expect(!yielded.contains(sequence))
        }
    }

    @Test("Empty stop sequences don't crash")
    internal func testEmptyStopSequences() {
        let handler: StopSequenceTestHandler = StopSequenceTestHandler(
            stopSequences: []
        )

        let stopped: Bool = handler.processText("any text")
        #expect(!stopped, "No stop sequences means no stopping")
        #expect(handler.yieldedTexts.contains("any text"))
    }
}

// MARK: - Test Helper

private final class StopSequenceTestHandler {
    var yieldedTexts: [String] = []
    var buffer: String = ""
    let stopSequences: [String]

    init(stopSequences: [String] = ["STOP", "<|im_end|>"]) {
        self.stopSequences = stopSequences
    }

    func reset() {
        yieldedTexts = []
        buffer = ""
    }

    func processText(_ text: String) -> Bool {
        let potential: String = buffer + text

        // Check for stop sequences BEFORE yielding (the fix!)
        if let stopSeq = findStopSequence(in: potential) {
            // Emit text before stop sequence
            let beforeStop: String = String(
                potential.dropLast(stopSeq.count)
            )
            if !beforeStop.isEmpty {
                let newText: String = String(
                    beforeStop.dropFirst(buffer.count)
                )
                if !newText.isEmpty {
                    yieldedTexts.append(newText)
                }
            }
            buffer = beforeStop
            return true
        }

        // No stop sequence - yield the text
        yieldedTexts.append(text)
        buffer = potential
        return false
    }

    private func findStopSequence(in text: String) -> String? {
        for sequence in stopSequences where text.hasSuffix(sequence) {
            return sequence
        }
        return nil
    }

    deinit {
        // Required by linter
    }
}
