import Testing
@testable import Abstractions

@Suite("Harmony Architecture Tests")
struct HarmonyArchitectureTests {
    @Test("Harmony architecture case exists")
    func testHarmonyArchitectureExists() {
        // Test that the harmony case exists in Architecture enum
        let harmony = Architecture.harmony
        #expect(harmony.rawValue == "harmony")
    }

    @Test("Harmony architecture display name")
    func testHarmonyDisplayName() {
        let harmony = Architecture.harmony
        #expect(harmony.displayName == "GPT-OSS")
        #expect(harmony.localizedDisplayName == "GPT-OSS")
    }

    @Test("Harmony architecture detection from model name")
    func testHarmonyDetection() {
        let testCases: [(name: String, expected: Architecture)] = [
            ("gpt-4-harmony", .harmony),
            ("harmony-1b", .harmony),
            ("openai-harmony", .harmony),
            ("Harmony-7B", .harmony)
        ]

        for (name, expected) in testCases {
            let detected = Architecture.detect(from: name)
            #expect(detected == expected, "Failed for \(name): expected \(expected), got \(detected)")
        }
    }

    @Test("Harmony architecture with version detection")
    func testHarmonyVersionDetection() {
        let testCases: [(name: String, expectedArch: Architecture, expectedVersion: String?)] = [
            ("harmony", .harmony, nil),
            ("harmony-1", .harmony, "1"),
            ("harmony-2.0", .harmony, "2.0"),
            ("harmony-v1", .harmony, "v1")
        ]

        for (name, expectedArch, expectedVersion) in testCases {
            let (arch, version) = Architecture.detectWithVersion(from: name)
            #expect(arch == expectedArch, "Failed for \(name): expected \(expectedArch), got \(arch)")
            #expect(version == expectedVersion, "Failed version for \(name)")
        }
    }

    @Test("Harmony is included in allCases")
    func testHarmonyInAllCases() {
        let allCases = Architecture.allCases
        #expect(allCases.contains(.harmony))
    }
}
