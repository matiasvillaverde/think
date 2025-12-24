import MLX
@testable import MLXSession
import Testing

@Suite("Quantization mode handling")
struct QuantizationModeTests {
    @Test("Non-affine quantization modes are detected")
    func nonAffineModes() {
        var mxfp4 = BaseConfiguration.Quantization(groupSize: 32, bits: 4)
        mxfp4.quantizationMode = "mxfp4"
        #expect(quantizationMode(for: mxfp4) == .mxfp4)
        #expect(isNonAffineQuantization(mxfp4))

        var mxfp8 = BaseConfiguration.Quantization(groupSize: 32, bits: 8)
        mxfp8.quantizationMode = "mxfp8"
        #expect(quantizationMode(for: mxfp8) == .mxfp8)
        #expect(isNonAffineQuantization(mxfp8))

        var nvfp4 = BaseConfiguration.Quantization(groupSize: 16, bits: 4)
        nvfp4.quantizationMode = "nvfp4"
        #expect(quantizationMode(for: nvfp4) == .nvfp4)
        #expect(isNonAffineQuantization(nvfp4))
    }

    @Test("Affine quantization modes are not flagged")
    func affineMode() {
        let affine = BaseConfiguration.Quantization(groupSize: 64, bits: 4)
        #expect(quantizationMode(for: affine) == .affine)
        #expect(isNonAffineQuantization(affine) == false)
    }

    @Test("Unknown quantization mode defaults to affine")
    func unknownModeDefaultsToAffine() {
        var quantization = BaseConfiguration.Quantization(groupSize: 64, bits: 4)
        quantization.quantizationMode = "unknown"
        #expect(quantizationMode(for: quantization) == .affine)
        #expect(isNonAffineQuantization(quantization) == false)
    }
}
