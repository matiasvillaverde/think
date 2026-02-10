import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

/// Tests for LabelFactory and error handling
@Suite("LabelFactory Tests")
internal struct LabelFactoryTests {
    @Test(
        "Creates ChatML labels for supported architectures",
        arguments: [
            Architecture.yi,
            .smol,
            .gemma,
            .deepseek,
            .chatglm,
            .phi,
            .phi4,
            .falcon,
            .baichuan
        ]
    )
    func testChatMLCreation(architecture: Architecture) throws {
        let labels: any StopSequenceLabels = try LabelFactory.createLabels(for: architecture)
        #expect(labels is ChatMLLabels)
    }

    @Test(
        "Creates Harmony labels for Harmony/GPT architectures",
        arguments: [Architecture.harmony, .gpt, .unknown]
    )
    func testHarmonyCreation(architecture: Architecture) throws {
        let labels: any StopSequenceLabels = try LabelFactory.createLabels(for: architecture)
        #expect(labels is HarmonyLabels)
    }

    @Test("Creates Qwen labels for Qwen architecture")
    func testQwenCreation() throws {
        let labels: any StopSequenceLabels = try LabelFactory.createLabels(for: .qwen)
        #expect(labels is QwenLabels)
    }

    @Test("Creates Llama3 labels for Llama architecture")
    func testLlama3Creation() throws {
        let labels: any StopSequenceLabels = try LabelFactory.createLabels(for: .llama)
        #expect(labels is Llama3Labels)
    }

    @Test(
        "Creates Mistral labels for Mistral/Mixtral architectures",
        arguments: [Architecture.mistral, .mixtral]
    )
    func testMistralCreation(architecture: Architecture) throws {
        let labels: any StopSequenceLabels = try LabelFactory.createLabels(for: architecture)
        #expect(labels is MistralLabels)
    }

    @Test(
        "Throws error for unsupported architectures",
        arguments: [
            Architecture.bert,
            .t5,
            .stableDiffusion,
            .flux,
            .whisper
        ]
    )
    func testUnsupportedArchitectures(architecture: Architecture) {
        #expect(throws: LabelError.unsupportedArchitecture(architecture)) {
            try LabelFactory.createLabels(for: architecture)
        }
    }

    @Test("LabelError provides meaningful descriptions")
    func testErrorDescriptions() {
        let error: LabelError = LabelError.unsupportedArchitecture(.stableDiffusion)

        #expect(error.errorDescription != nil)
        #expect(error.failureReason != nil)
        #expect(error.recoverySuggestion != nil)
        #expect(error.helpAnchor == "label-unsupported-architecture")
    }

    @Test("LabelError equality works correctly")
    func testErrorEquality() {
        let error1: LabelError = LabelError.unsupportedArchitecture(.bert)
        let error2: LabelError = LabelError.unsupportedArchitecture(.bert)
        let error3: LabelError = LabelError.unsupportedArchitecture(.t5)

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test("Type-specific factory methods work correctly")
    func testTypeSpecificFactoryMethods() {
        // Create a mock model
        let mockModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "qwen/qwen-test",
            architecture: .qwen,
            backend: .mlx,
            locationKind: .huggingFace,
        )

        // Test Qwen-specific factory
        let qwenLabels: QwenLabels? = LabelFactory.createQwenLabels(for: mockModel)
        #expect(qwenLabels != nil)

        // Test with wrong architecture
        let wrongModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "bert/bert-test",
            architecture: .bert,
            backend: .mlx,
            locationKind: .huggingFace,
        )

        let noLabels: QwenLabels? = LabelFactory.createQwenLabels(for: wrongModel)
        #expect(noLabels == nil)
    }
}
