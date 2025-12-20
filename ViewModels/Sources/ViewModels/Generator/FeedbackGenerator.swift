import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

internal final class FeedbackGenerator: @unchecked Sendable {
    // MARK: - Constants

    /// Medium haptic intensity for first beat of end pattern
    private static let mediumEndIntensity: CGFloat = 0.7

    /// Heavy haptic intensity for second beat of end pattern
    private static let heavyEndIntensity: CGFloat = 0.9

    /// Maximum haptic intensity for final beat of end pattern
    private static let maxEndIntensity: CGFloat = 1.0

    /// Pause duration between first and second beat in nanoseconds (180ms)
    private static let firstPauseNanoseconds: UInt64 = 180_000_000

    /// Pause duration between second and final beat in nanoseconds (100ms)
    private static let secondPauseNanoseconds: UInt64 = 100_000_000

#if os(iOS)

    private var lightFeedbackGenerator: UIImpactFeedbackGenerator?
    private var mediumFeedbackGenerator: UIImpactFeedbackGenerator?
    private var heavyFeedbackGenerator: UIImpactFeedbackGenerator?
#endif

    init() {
        // Create haptic feedback generators for iOS
        #if os(iOS)
        Task {
            lightFeedbackGenerator = await UIImpactFeedbackGenerator(style: .light)
            mediumFeedbackGenerator = await UIImpactFeedbackGenerator(style: .medium)
            heavyFeedbackGenerator = await UIImpactFeedbackGenerator(style: .heavy)

            // Prepare generators ahead of time for more responsive feedback
            await lightFeedbackGenerator?.prepare()
            await mediumFeedbackGenerator?.prepare()
            await heavyFeedbackGenerator?.prepare()
        }
        #endif
    }

    deinit {
        // Resources are automatically cleaned up
    }

    func image() async {
        #if os(iOS)
        await heavyFeedbackGenerator?.impactOccurred()
        #endif
    }

    // Tango-like ending pattern when complete
    func end() async throws {
        #if os(iOS)
        // First beat - medium
        await mediumFeedbackGenerator?.impactOccurred(intensity: Self.mediumEndIntensity)
        try await Task.sleep(nanoseconds: Self.firstPauseNanoseconds) // 180ms pause

        // Second beat - heavier
        await heavyFeedbackGenerator?.impactOccurred(intensity: Self.heavyEndIntensity)
        try await Task.sleep(nanoseconds: Self.secondPauseNanoseconds) // 100ms pause

        // Final punctuation - strongest
        await heavyFeedbackGenerator?.impactOccurred(intensity: Self.maxEndIntensity)
        #endif
    }
}
