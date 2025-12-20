import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("ModelFile Tests")
struct ModelFileTests {
    @Test("ModelFile initialization")
    func testInitialization() {
        let file: ModelFile = ModelFile(
            path: "models/test.safetensors",
            size: 1_024 * 1_024 * 100, // 100MB
            sha: "abc123"
        )

        #expect(file.path == "models/test.safetensors")
        #expect(file.size == 104_857_600)
        #expect(file.sha == "abc123")
    }

    @Test("ModelFile without optional values")
    func testInitializationWithoutOptionals() {
        let file: ModelFile = ModelFile(path: "config.json")

        #expect(file.path == "config.json")
        #expect(file.size == nil)
        #expect(file.sha == nil)
    }

    @Test("Filename extraction")
    func testFilename() {
        let file1: ModelFile = ModelFile(path: "models/weights.safetensors")
        #expect(file1.filename == "weights.safetensors")

        let file2: ModelFile = ModelFile(path: "config.json")
        #expect(file2.filename == "config.json")

        let file3: ModelFile = ModelFile(path: "deep/nested/path/model.gguf")
        #expect(file3.filename == "model.gguf")
    }

    @Test("File extension extraction")
    func testFileExtension() {
        #expect(ModelFile(path: "model.safetensors").fileExtension == "safetensors")
        #expect(ModelFile(path: "model.GGUF").fileExtension == "gguf")
        #expect(ModelFile(path: "CONFIG.JSON").fileExtension == "json")
        #expect(ModelFile(path: "noextension").fileExtension.isEmpty)
    }

    @Test("Formatted size")
    func testFormattedSize() {
        let file1: ModelFile = ModelFile(path: "test", size: 1_024)
        #expect(file1.formattedSize == "1 KB")

        let file2: ModelFile = ModelFile(path: "test", size: 1_024 * 1_024 * 100)
        // ByteCountFormatter may format this as "104.9 MB" or similar
        #expect(file2.formattedSize.contains("MB"))

        let file3: ModelFile = ModelFile(path: "test", size: nil)
        #expect(file3.formattedSize == "Unknown size")
    }

    @Test("Model file detection")
    func testIsModelFile() {
        #expect(ModelFile(path: "model.safetensors").isModelFile == true)
        #expect(ModelFile(path: "model.gguf").isModelFile == true)
        #expect(ModelFile(path: "model.bin").isModelFile == true)
        #expect(ModelFile(path: "model.mlmodel").isModelFile == true)
        #expect(ModelFile(path: "model.mlpackage").isModelFile == true)
        #expect(ModelFile(path: "model.pt").isModelFile == true)
        #expect(ModelFile(path: "model.h5").isModelFile == true)

        #expect(ModelFile(path: "config.json").isModelFile == false)
        #expect(ModelFile(path: "README.md").isModelFile == false)
    }

    @Test("Config file detection")
    func testIsConfigFile() {
        #expect(ModelFile(path: "config.json").isConfigFile == true)
        #expect(ModelFile(path: "settings.yaml").isConfigFile == true)
        #expect(ModelFile(path: "config.yml").isConfigFile == true)
        #expect(ModelFile(path: "Info.plist").isConfigFile == true)

        #expect(ModelFile(path: "model.safetensors").isConfigFile == false)
        #expect(ModelFile(path: "README.md").isConfigFile == false)
    }

    @Test("ModelFile equality")
    func testEquality() {
        let file1: ModelFile = ModelFile(path: "test.bin", size: 100, sha: "abc")
        let file2: ModelFile = ModelFile(path: "test.bin", size: 100, sha: "abc")
        let file3: ModelFile = ModelFile(path: "other.bin", size: 100, sha: "abc")

        #expect(file1 == file2)
        #expect(file1 != file3)
    }

    @Test("ModelFile is Hashable")
    func testHashable() {
        let file: ModelFile = ModelFile(path: "test.bin", size: 100)

        var set: Set<ModelFile> = Set<ModelFile>()
        set.insert(file)

        #expect(set.count == 1)
        #expect(set.contains(file))
    }

    @Test("ModelFile is Codable")
    func testCodable() throws {
        let original: ModelFile = ModelFile(
            path: "models/test.safetensors",
            size: 1_024 * 1_024,
            sha: "sha256:abcdef123456"
        )

        let encoder: JSONEncoder = JSONEncoder()
        let data: Data = try encoder.encode(original)

        let decoder: JSONDecoder = JSONDecoder()
        let decoded: ModelFile = try decoder.decode(ModelFile.self, from: data)

        #expect(decoded.path == original.path)
        #expect(decoded.size == original.size)
        #expect(decoded.sha == original.sha)
    }
}
