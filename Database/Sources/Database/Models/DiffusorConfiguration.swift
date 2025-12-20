import Foundation
import SwiftData
import Abstractions

@Model
@DebugDescription
public final class DiffusorConfiguration: Identifiable, Equatable {
    // MARK: - Identity

    /// A unique identifier for the entity.
    @Attribute(.unique)
    public private(set) var id: UUID = UUID()

    /// The creation date of the entity.
    @Attribute()
    public private(set) var createdAt: Date = Date()

    // MARK: - Metadata

    /// The "negative prompt" for image generation to exclude undesired aspects.
    @Attribute()
    public private(set) var negativePrompt: String

    /// The number of diffusion steps.
    @Attribute()
    public private(set) var steps: Int

    @Attribute()
    public private(set) var seed: UInt64

    @Attribute()
    public private(set) var cfgWeight: Float

    @Attribute()
    public private(set) var imageCount: Int

    @Attribute()
    public private(set) var decodingBatchSize: Int

    @Attribute()
    public private(set) var latentWidth: Int = 64
    
    @Attribute()
    public private(set) var latentHeight: Int = 64
    
    /// Computed property for backward compatibility
    public var latentSize: [Int] {
        [latentWidth, latentHeight]
    }

    // MARK: - Initializer

    public init(
        negativePrompt: String = "",
        steps: Int = 25,
        seed: UInt64 = 42,
        cfgWeight: Float = 7.5,
        imageCount: Int = 1,
        decodingBatchSize: Int = 1,
        latentSize: [Int] = [64, 64]
    ) {
        self.negativePrompt = negativePrompt
        self.steps = steps
        self.seed = seed
        self.cfgWeight = cfgWeight
        self.imageCount = imageCount
        self.decodingBatchSize = decodingBatchSize
        // Extract width and height from array
        self.latentWidth = latentSize.first ?? 64
        self.latentHeight = latentSize.count > 1 ? latentSize[1] : 64
    }

    /// A convenience default configuration for quick creation.
    public static var `default`: DiffusorConfiguration {
         DiffusorConfiguration(negativePrompt: """
deformed iris, deformed pupils, semi-realistic, 3d render, cartoon,
sketch, low quality, ugly, duplicate, bad anatomy, extra fingers, mutated hands,
poorly drawn hands, mutation, blurry, extra limbs
""")
    }

    public func toSendable(prompt: String, negative: String? = nil) -> ImageConfiguration {
        ImageConfiguration(
            prompt: prompt,
            id: id,
            negativePrompt: negative ?? self.negativePrompt,
            steps: steps,
            seed: seed,
            cfgWeight: cfgWeight,
            imageCount: imageCount,
            decodingBatchSize: decodingBatchSize,
            latentSize: latentSize
        )
    }
}

extension DiffusorConfiguration {
    @MainActor public static let preview: DiffusorConfiguration = {
        .default
    }()
}
