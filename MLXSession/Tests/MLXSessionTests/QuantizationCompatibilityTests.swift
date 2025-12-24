import MLX
@testable import MLXSession
import Testing

@Suite("Quantization compatibility")
struct QuantizationCompatibilityTests {
    @Test("Group size compatibility checks last dimension")
    func groupSizeCompatibility() {
        let weight = MLXArray.zeros([4, 64])
        #expect(isQuantizationGroupSizeCompatible(weight: weight, groupSize: 64))
        #expect(isQuantizationGroupSizeCompatible(weight: weight, groupSize: 32))
        #expect(isQuantizationGroupSizeCompatible(weight: weight, groupSize: 16))
        #expect(isQuantizationGroupSizeCompatible(weight: weight, groupSize: 7) == false)
    }

    @Test("Group size compatibility rejects invalid inputs")
    func groupSizeCompatibilityInvalid() {
        let weight = MLXArray.zeros([4, 64])
        #expect(isQuantizationGroupSizeCompatible(weight: weight, groupSize: 0) == false)
    }
}
