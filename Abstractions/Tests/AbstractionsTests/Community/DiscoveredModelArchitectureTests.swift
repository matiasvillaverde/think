import Testing
@testable import Abstractions
import Foundation

@Suite("DiscoveredModel Architecture Detection")
struct DiscoveredModelArchitectureTests {
    @Test("Detect Llama architecture from model ID")
    @MainActor
    func testLlamaArchitectureDetection() {
        let model = DiscoveredModel(
            id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            name: "Llama-3.2-3B-Instruct-4bit",
            author: "mlx-community",
            downloads: 1000,
            likes: 50,
            tags: ["text-generation"],
            lastModified: Date()
        )

        #expect(model.inferredArchitecture == .llama)
    }

    @Test("Detect Gemma architecture from model ID")
    @MainActor
    func testGemmaArchitectureDetection() {
        let model = DiscoveredModel(
            id: "google/gemma-2-2b-it",
            name: "gemma-2-2b-it",
            author: "google",
            downloads: 5000,
            likes: 200,
            tags: ["conversational"],
            lastModified: Date()
        )

        #expect(model.inferredArchitecture == .gemma)
    }

    @Test("Detect Mistral architecture from model ID")
    @MainActor
    func testMistralArchitectureDetection() {
        let model = DiscoveredModel(
            id: "mistralai/Mistral-7B-v0.1",
            name: "Mistral-7B-v0.1",
            author: "mistralai",
            downloads: 10000,
            likes: 500,
            tags: ["text-generation", "instruct"],
            lastModified: Date()
        )

        #expect(model.inferredArchitecture == .mistral)
    }

    @Test("Detect Mixtral architecture from model ID")
    @MainActor
    func testMixtralArchitectureDetection() {
        let model = DiscoveredModel(
            id: "mistralai/Mixtral-8x7B-v0.1",
            name: "Mixtral-8x7B-v0.1",
            author: "mistralai",
            downloads: 8000,
            likes: 400,
            tags: ["text-generation", "moe"],
            lastModified: Date()
        )

        #expect(model.inferredArchitecture == .mixtral)
    }

    @Test("Detect Qwen architecture from model ID")
    @MainActor
    func testQwenArchitectureDetection() {
        let model = DiscoveredModel(
            id: "Qwen/Qwen2-7B-Instruct",
            name: "Qwen2-7B-Instruct",
            author: "Qwen",
            downloads: 3000,
            likes: 150,
            tags: ["text-generation", "chat"],
            lastModified: Date()
        )

        #expect(model.inferredArchitecture == .qwen)
    }

    @Test("Return unknown architecture for unrecognized models")
    @MainActor
    func testUnknownArchitectureFallback() {
        let model = DiscoveredModel(
            id: "some-org/unknown-model-v1",
            name: "unknown-model-v1",
            author: "some-org",
            downloads: 100,
            likes: 5,
            tags: ["experimental"],
            lastModified: Date()
        )

        #expect(model.inferredArchitecture == .unknown)
    }

    @Test("Case-insensitive architecture detection")
    @MainActor
    func testCaseInsensitiveDetection() {
        let model = DiscoveredModel(
            id: "org/LLAMA-model",
            name: "LLAMA-model",
            author: "org",
            downloads: 500,
            likes: 25,
            tags: [],
            lastModified: Date()
        )

        #expect(model.inferredArchitecture == .llama)
    }

    @Test("Priority for multiple architecture matches")
    @MainActor
    func testMultipleMatchesPriority() {
        // Mixtral should be detected before Mistral due to priority order
        let model = DiscoveredModel(
            id: "org/mixtral-based-model",
            name: "mixtral-based-model",
            author: "org",
            downloads: 1500,
            likes: 75,
            tags: ["mistral", "mixtral"],
            lastModified: Date()
        )

        #expect(model.inferredArchitecture == .mixtral)
    }

    @Test("Detect architecture from tags when not in model ID")
    @MainActor
    func testArchitectureDetectionFromTags() {
        let model = DiscoveredModel(
            id: "org/custom-model-name",
            name: "custom-model-name",
            author: "org",
            downloads: 2000,
            likes: 100,
            tags: ["gemma", "text-generation", "fine-tuned"],
            lastModified: Date()
        )

        #expect(model.inferredArchitecture == .gemma)
    }

    @Test("Detect architecture for various known architectures")
    @MainActor
    func testVariousArchitectures() {
        let testCases: [(id: String, expected: Architecture)] = [
            ("microsoft/phi-2", .phi),
            ("deepseek-ai/deepseek-coder-6.7b", .deepseek),
            ("01-ai/Yi-34B", .yi),
            ("baichuan-inc/Baichuan2-7B", .baichuan),
            ("THUDM/chatglm3-6b", .chatglm),
            ("tiiuae/falcon-7b", .falcon),
            ("google/flan-t5-base", .t5),
            ("bert-base-uncased", .bert),
            ("openai/gpt-3.5-turbo", .harmony),
            ("stabilityai/stable-diffusion-xl", .stableDiffusion),
            ("black-forest-labs/FLUX.1-dev", .flux),
            ("openai/whisper-large-v3", .whisper)
        ]

        for (id, expected) in testCases {
            let model = DiscoveredModel(
                id: id,
                name: id.components(separatedBy: "/").last ?? id,
                author: id.components(separatedBy: "/").first ?? "unknown",
                downloads: 1000,
                likes: 50,
                tags: [],
                lastModified: Date()
            )

            #expect(model.inferredArchitecture == expected,
                   "Failed for \(id): expected \(expected), got \(model.inferredArchitecture)")
        }
    }
}
