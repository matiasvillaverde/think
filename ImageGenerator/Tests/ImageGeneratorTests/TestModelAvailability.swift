import CoreML
import Foundation

enum TestModelAvailability {
    private static let cachedAvailability: Bool = {
        guard let modelRootURL = Bundle.module.url(
            forResource: "TestModel",
            withExtension: nil,
            subdirectory: "Resources"
        ) else {
            return false
        }

        let textEncoderURL = modelRootURL.appendingPathComponent("TextEncoder.mlmodelc")
        guard FileManager.default.fileExists(atPath: textEncoderURL.path) else {
            return false
        }

        do {
            _ = try MLModel(contentsOf: textEncoderURL)
            return true
        } catch {
            return false
        }
    }()

    static var isAvailable: Bool {
        cachedAvailability
    }
}
