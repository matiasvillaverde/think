@testable import ModelDownloader
import Testing

@Suite("CoreML Detector Tests")
struct CoreMLDetectorTests {
    @Test("Detect CoreML model from model ID")
    func detectFromModelId() {
        #expect(CoreMLDetector.isCoreMLModel(modelId: "apple/coreml-stable-diffusion"))
        #expect(CoreMLDetector.isCoreMLModel(modelId: "huggingface/coreml-bert"))
        #expect(CoreMLDetector.isCoreMLModel(modelId: "COREML-model"))
        #expect(!CoreMLDetector.isCoreMLModel(modelId: "microsoft/phi-2"))
    }

    @Test("Detect CoreML model from backend")
    func detectFromBackend() {
        #expect(CoreMLDetector.isCoreMLModel(modelId: "any-model", backend: .coreml))
        #expect(!CoreMLDetector.isCoreMLModel(modelId: "any-model", backend: .mlx))
        #expect(!CoreMLDetector.isCoreMLModel(modelId: "any-model", backend: .gguf))
    }

    @Test("Detect CoreML path")
    func detectCoreMLPath() {
        // Direct CoreML indicators
        #expect(CoreMLDetector.isCoreMLPath("models/coreml/model.zip"))
        #expect(CoreMLDetector.isCoreMLPath("model.mlmodel"))
        #expect(CoreMLDetector.isCoreMLPath("model.mlmodelc.zip"))

        // Variant paths
        #expect(CoreMLDetector.isCoreMLPath("split-einsum/model.zip"))
        #expect(CoreMLDetector.isCoreMLPath("split_einsum/model.zip"))
        #expect(CoreMLDetector.isCoreMLPath("original/model.zip"))
        #expect(CoreMLDetector.isCoreMLPath("compiled/model.zip"))
        #expect(CoreMLDetector.isCoreMLPath("packages/model.zip"))

        // Non-CoreML paths
        #expect(!CoreMLDetector.isCoreMLPath("models/gguf/model.bin"))
        #expect(!CoreMLDetector.isCoreMLPath("safetensors/model.safetensors"))
    }

    @Test("Detect CoreML variants")
    func detectVariants() {
        #expect(CoreMLDetector.isCoreMLVariant("split-einsum/model.zip"))
        #expect(CoreMLDetector.isCoreMLVariant("split_einsum/model.zip"))
        #expect(CoreMLDetector.isCoreMLVariant("original/model.zip"))
        #expect(!CoreMLDetector.isCoreMLVariant("compiled/model.zip"))
        #expect(!CoreMLDetector.isCoreMLVariant("models/model.zip"))
    }

    @Test("Get CoreML variant type")
    func getVariantType() {
        #expect(CoreMLDetector.getCoreMLVariant("split-einsum/model.zip") == .splitEinsum)
        #expect(CoreMLDetector.getCoreMLVariant("split_einsum/model.zip") == .splitEinsum)
        #expect(CoreMLDetector.getCoreMLVariant("original/model.zip") == .original)
        #expect(CoreMLDetector.getCoreMLVariant("compiled/model.zip") == .compiled)
        #expect(CoreMLDetector.getCoreMLVariant("packages/model.zip") == .packages)
        #expect(CoreMLDetector.getCoreMLVariant("models/model.zip") == nil)
    }

    @Test("Case insensitive detection")
    func caseInsensitiveDetection() {
        #expect(CoreMLDetector.isCoreMLModel(modelId: "Apple/CoreML-Model"))
        #expect(CoreMLDetector.isCoreMLModel(modelId: "APPLE/COREML-MODEL"))
        #expect(CoreMLDetector.isCoreMLPath("SPLIT-EINSUM/Model.ZIP"))
        #expect(CoreMLDetector.isCoreMLPath("Original/MODEL.zip"))
    }
}
