import Abstractions
@testable import ModelDownloader
import Testing

@Suite("SendableModel.Backend Tests")
internal struct BackendTests {
    @Test("File patterns for MLX backend")
    func testMLXFilePatterns() {
        let backend: SendableModel.Backend = .mlx
        let patterns: [String] = backend.filePatterns

        let expected: [String] = ["*.safetensors", "*.json", "*.plist"]
        #expect(patterns == expected)
    }

    @Test("File patterns for GGUF backend")
    func testGGUFFilePatterns() {
        let backend: SendableModel.Backend = .gguf
        let patterns: [String] = backend.filePatterns

        let expected: [String] = ["*.gguf", "*.json"]
        #expect(patterns == expected)
    }

    @Test("File patterns for CoreML backend")
    func testCoreMLFilePatterns() {
        let backend: SendableModel.Backend = .coreml
        let patterns: [String] = backend.filePatterns

        let expected: [String] = ["*.zip", "*.mlmodel", "*.mlpackage", "*.json", "*.plist"]
        #expect(patterns == expected)
    }

    @Test("Backend raw values")
    func testBackendRawValues() {
        #expect(SendableModel.Backend.mlx.rawValue == "mlx")
        #expect(SendableModel.Backend.gguf.rawValue == "gguf")
        #expect(SendableModel.Backend.coreml.rawValue == "coreml")
    }

    @Test("Backend directory names")
    func testBackendDirectoryNames() {
        // Backend raw values are used as directory names
        #expect(SendableModel.Backend.mlx.rawValue == "mlx")
        #expect(SendableModel.Backend.gguf.rawValue == "gguf")
        #expect(SendableModel.Backend.coreml.rawValue == "coreml")
    }

    @Test("All cases are covered")
    func testAllCases() {
        let allCases: [SendableModel.Backend] = SendableModel.Backend.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.mlx))
        #expect(allCases.contains(.gguf))
        #expect(allCases.contains(.coreml))
    }

    @Test("Backend is Sendable")
    func testSendable() {
        // This test ensures SendableModel.Backend conforms to Sendable
        let backend: any Sendable = SendableModel.Backend.mlx
        #expect(backend as? SendableModel.Backend == SendableModel.Backend.mlx)
    }
}
