import MLX
@testable import MLXSession
import Testing

@Suite("Stream defaults")
struct StreamDefaultTests {
    @Test("Default stream respects task-local overrides")
    func defaultStreamUsesTaskLocalOverride() {
        let deviceDefault = Stream.defaultStream(Device.defaultDevice())
        #expect(StreamOrDevice.default.stream == deviceDefault)

        let cpuDefault = Stream.defaultStream(.cpu)
        var scopedStream: Stream?
        Stream.withNewDefaultStream(device: .cpu) {
            scopedStream = StreamOrDevice.default.stream
            #expect(scopedStream != cpuDefault)
        }
    }
}
