@testable import MLXSession
import Testing

@Suite("Stop sequence detection")
struct StopSequenceDetectorTests {
    @Test("Detects sequence across chunks")
    func detectsAcrossChunks() {
        var detector = StopSequenceDetector(sequences: ["lo wor"])
        #expect(detector.append("Hel") == false)
        #expect(detector.append("lo ") == false)
        #expect(detector.append("world") == true)
    }

    @Test("Handles multiple sequences")
    func detectsMultipleSequences() {
        var detector = StopSequenceDetector(sequences: ["END", "<stop>"])
        #expect(detector.append("hello ") == false)
        #expect(detector.append("<stop>") == true)
    }

    @Test("Ignores empty sequences")
    func ignoresEmptySequences() {
        var detector = StopSequenceDetector(sequences: [""])
        #expect(detector.append("anything") == false)
    }
}
