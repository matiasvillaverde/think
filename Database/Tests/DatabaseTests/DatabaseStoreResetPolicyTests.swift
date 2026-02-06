import Foundation
import OSLog
import Testing
@testable import Database

@Suite("Database Store Reset Policy Tests")
struct DatabaseStoreResetPolicyTests {
    @Test("Resets store when schema version is outdated")
    func resetsStoreWhenVersionOutdated() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store", isDirectory: true)
        try FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)

        let versionURL = storeURL.appendingPathExtension("version")
        try "0".write(to: versionURL, atomically: true, encoding: .utf8)

        DatabaseStoreResetPolicy.prepareStoreIfNeeded(storeURL: storeURL, logger: Logger.database)

        #expect(!FileManager.default.fileExists(atPath: storeURL.path))
        let updatedVersion = try String(contentsOf: versionURL, encoding: .utf8)
        #expect(Int(updatedVersion.trimmingCharacters(in: .whitespacesAndNewlines)) ==
            DatabaseStoreResetPolicy.currentSchemaVersion)
    }

    @Test("Keeps store when schema version is current")
    func keepsStoreWhenVersionCurrent() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store", isDirectory: true)
        try FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)

        let versionURL = storeURL.appendingPathExtension("version")
        try String(DatabaseStoreResetPolicy.currentSchemaVersion)
            .write(to: versionURL, atomically: true, encoding: .utf8)

        DatabaseStoreResetPolicy.prepareStoreIfNeeded(storeURL: storeURL, logger: Logger.database)

        #expect(FileManager.default.fileExists(atPath: storeURL.path))
        let updatedVersion = try String(contentsOf: versionURL, encoding: .utf8)
        #expect(Int(updatedVersion.trimmingCharacters(in: .whitespacesAndNewlines)) ==
            DatabaseStoreResetPolicy.currentSchemaVersion)
    }
}
