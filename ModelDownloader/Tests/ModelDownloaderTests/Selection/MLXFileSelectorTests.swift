import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("MLXFileSelector Tests")
struct MLXFileSelectorTests {
    @Test("Selects required MLX files and excludes unrelated files")
    func selectsRequiredFiles() async {
        let files: [ModelFile] = [
            ModelFile(path: "model.safetensors", size: 10),
            ModelFile(path: "config.json", size: 1),
            ModelFile(path: "tokenizer.json", size: 1),
            ModelFile(path: "tokenizer_config.json", size: 1),
            ModelFile(path: "special_tokens_map.json", size: 1),
            ModelFile(path: "vocab.json", size: 1),
            ModelFile(path: "merges.txt", size: 1),
            ModelFile(path: "README.md", size: 1),
            ModelFile(path: "pytorch_model.bin", size: 1)
        ]

        let selector: MLXFileSelector = MLXFileSelector()
        let selected: [ModelFile] = await selector.selectFiles(from: files)

        let selectedPaths: Set<String> = Set(selected.map(\.path))

        #expect(selectedPaths.contains("model.safetensors"))
        #expect(selectedPaths.contains("config.json"))
        #expect(selectedPaths.contains("tokenizer.json"))
        #expect(selectedPaths.contains("tokenizer_config.json"))
        #expect(selectedPaths.contains("special_tokens_map.json"))
        #expect(selectedPaths.contains("vocab.json"))
        #expect(selectedPaths.contains("merges.txt"))
        #expect(!selectedPaths.contains("README.md"))
        #expect(!selectedPaths.contains("pytorch_model.bin"))
    }

    @Test("Returns empty list when no files are provided")
    func handlesEmptyInput() async {
        let selector: MLXFileSelector = MLXFileSelector()
        let selected: [ModelFile] = await selector.selectFiles(from: [])
        #expect(selected.isEmpty)
    }
}
