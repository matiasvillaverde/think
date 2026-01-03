@testable import MLXSession
import Testing

@Suite("StopFlag Tests")
struct StopFlagTests {
    @Test("StopFlag defaults to false and can be toggled")
    func stopFlagToggles() {
        let flag = StopFlag()
        #expect(flag.get() == false)

        flag.set(true)
        #expect(flag.get() == true)

        flag.reset()
        #expect(flag.get() == false)
    }
}
