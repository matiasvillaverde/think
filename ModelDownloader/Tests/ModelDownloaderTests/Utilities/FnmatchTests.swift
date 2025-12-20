import Foundation
@testable import ModelDownloader
import Testing

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// MARK: - Fnmatch Pattern Matching Tests

@Test("fnmatch should work with glob patterns")
internal func testFnmatchPatterns() {
    // Test basic filename matching
    let expectedMatch: Int32 = 0
    #expect(fnmatch("*.txt", "file.txt", 0) == expectedMatch)
    let expectedNoMatch: Int32 = 0
    #expect(fnmatch("*.txt", "file.json", 0) != expectedNoMatch)

    // Test path matching
    #expect(fnmatch("**/model.bin", "folder/model.bin", 0) == 0)
    #expect(fnmatch("**/model.bin", "deep/nested/folder/model.bin", 0) == 0)

    // Test specific patterns
    #expect(fnmatch("model-*.safetensors", "model-00001.safetensors", 0) == 0)
    #expect(fnmatch("model-*.safetensors", "model-00002.safetensors", 0) == 0)
    #expect(fnmatch("model-*.safetensors", "other-00001.safetensors", 0) != 0)

    // Test character classes
    #expect(fnmatch("file[0-9].txt", "file1.txt", 0) == 0)
    #expect(fnmatch("file[0-9].txt", "file9.txt", 0) == 0)
    #expect(fnmatch("file[0-9].txt", "fileA.txt", 0) != 0)

    // Test negation
    #expect(fnmatch("[!.]*.txt", "file.txt", 0) == 0)
    #expect(fnmatch("[!.]*.txt", ".hidden.txt", 0) != 0)
}

@Test("fnmatch should work with MLX model patterns")
internal func testMLXModelPatterns() {
    let mlxPattern: String = "*.safetensors"
    let weightPattern: String = "model*.safetensors"

    // Test MLX weight files
    #expect(fnmatch(mlxPattern, "model.safetensors", 0) == 0)
    #expect(fnmatch(mlxPattern, "model-00001-of-00002.safetensors", 0) == 0)
    #expect(fnmatch(weightPattern, "model-00001-of-00002.safetensors", 0) == 0)

    // Test config files should not match
    #expect(fnmatch(mlxPattern, "config.json", 0) != 0)
    #expect(fnmatch(mlxPattern, "tokenizer.json", 0) != 0)
}

@Test("fnmatch should work with CoreML model patterns")
internal func testCoreMLModelPatterns() {
    let coremlPattern: String = "*.mlpackage"
    let compiledPattern: String = "coreml*.mlpackage"

    // Test CoreML packages
    #expect(fnmatch(coremlPattern, "model.mlpackage", 0) == 0)
    #expect(fnmatch(coremlPattern, "coreml-model.mlpackage", 0) == 0)
    #expect(fnmatch(compiledPattern, "coreml-model.mlpackage", 0) == 0)

    // Test non-CoreML files should not match
    #expect(fnmatch(coremlPattern, "model.safetensors", 0) != 0)
    #expect(fnmatch(compiledPattern, "model.mlpackage", 0) != 0)
}

@Test("fnmatch should work with GGUF model patterns")
internal func testGGUFModelPatterns() {
    let ggufPattern: String = "*.gguf"
    let quantizedPattern: String = "*-Q*.gguf"

    // Test GGUF files
    #expect(fnmatch(ggufPattern, "model.gguf", 0) == 0)
    #expect(fnmatch(ggufPattern, "llama-2-7b.gguf", 0) == 0)

    // Test quantized GGUF files
    #expect(fnmatch(quantizedPattern, "model-Q4_K_M.gguf", 0) == 0)
    #expect(fnmatch(quantizedPattern, "llama-2-7b-Q8_0.gguf", 0) == 0)
    #expect(fnmatch(quantizedPattern, "model.gguf", 0) != 0)
}

@Test("fnmatch should handle exclude patterns")
internal func testExcludePatterns() {
    // Common exclude patterns
    let hiddenPattern: String = ".*"
    let tempPattern: String = "*.tmp"
    let backupPattern: String = "*~"

    // Test hidden files
    #expect(fnmatch(hiddenPattern, ".gitignore", 0) == 0)
    #expect(fnmatch(hiddenPattern, ".DS_Store", 0) == 0)
    #expect(fnmatch(hiddenPattern, "visible.txt", 0) != 0)

    // Test temp files
    #expect(fnmatch(tempPattern, "download.tmp", 0) == 0)
    #expect(fnmatch(tempPattern, "file.tmp", 0) == 0)
    #expect(fnmatch(tempPattern, "file.txt", 0) != 0)

    // Test backup files
    #expect(fnmatch(backupPattern, "file~", 0) == 0)
    #expect(fnmatch(backupPattern, "backup~", 0) == 0)
    #expect(fnmatch(backupPattern, "file.txt", 0) != 0)
}

@Test("fnmatch platform-specific imports should work")
internal func testPlatformSpecificImports() {
    // This test verifies that fnmatch is available on the current platform
    let result: Int32 = fnmatch("test", "test", 0)
    let expectedResult: Int32 = 0
    #expect(result == expectedResult)

    // Verify fnmatch constants are available
    #if canImport(Darwin)
    // On Darwin platforms
    #expect(FNM_NOESCAPE != 0)
    #expect(FNM_PATHNAME != 0)
    #else
    // On Linux platforms
    #expect(FNM_NOESCAPE != 0)
    #expect(FNM_PATHNAME != 0)
    #endif
}
