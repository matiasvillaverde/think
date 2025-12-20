import Foundation
@testable import Abstractions

/// Test utilities for creating mock DiscoveredModel instances
extension DiscoveredModel {
    /// Creates a mock DiscoveredModel for testing purposes
    /// - Parameters:
    ///   - id: The model ID (defaults to "test-model")
    ///   - community: Community prefix for the ID (optional)
    ///   - name: Model name (defaults to derived from ID)
    ///   - author: Model author (defaults to derived from ID)
    ///   - downloads: Download count (defaults to 1000)
    ///   - likes: Like count (defaults to 50)
    ///   - tags: Model tags (defaults to ["text-generation"])
    ///   - lastModified: Last modified date (defaults to current date)
    ///   - modelCard: Model card content (defaults to basic template)
    ///   - files: Model files (defaults to single safetensors file)
    ///   - detectedBackends: Detected backends (defaults to [.mlx])
    ///   - license: License type (defaults to "mit")
    ///   - licenseUrl: License URL (optional)
    ///   - imageUrls: Image URLs (defaults to nil for lazy loading)
    /// - Returns: A mock DiscoveredModel instance
    public static func createMock(
        id: String = "test-model",
        community: String? = nil,
        name: String? = nil,
        author: String? = nil,
        downloads: Int = 1000,
        likes: Int = 50,
        tags: [String] = ["text-generation"],
        lastModified: Date = Date(),
        modelCard: String? = nil,
        files: [ModelFile] = [],
        detectedBackends: [SendableModel.Backend] = [.mlx],
        license: String = "mit",
        licenseUrl: String? = nil,
        imageUrls: [String] = []
    ) -> DiscoveredModel {
        let fullId: String
        let derivedAuthor: String
        let derivedName: String

        if let community {
            fullId = "\(community)/\(id)"
            derivedAuthor = community
            derivedName = id
        } else {
            fullId = id
            let components = id.split(separator: "/")
            if components.count == 2 {
                derivedAuthor = String(components[0])
                derivedName = String(components[1])
            } else {
                derivedAuthor = "test-author"
                derivedName = id
            }
        }

        let finalFiles = files.isEmpty ? [
            ModelFile(
                path: "model.safetensors",
                size: 1024 * 1024 * 100 // 100MB
            )
        ] : files

        let defaultModelCard = """
        # \(derivedName)

        This is a test model for \(derivedAuthor).

        ## Model Details
        - Model Type: Test Model
        - Language: English
        - License: \(license)
        """

        let model = DiscoveredModel(
            id: fullId,
            name: name ?? derivedName,
            author: author ?? derivedAuthor,
            downloads: downloads,
            likes: likes,
            tags: tags,
            lastModified: lastModified,
            files: finalFiles,
            license: license,
            licenseUrl: licenseUrl
        )

        // Enrich with progressive data
        let enrichedDetails = EnrichedModelDetails(
            modelCard: modelCard ?? defaultModelCard,
            cardData: nil,
            imageUrls: imageUrls,
            detectedBackends: detectedBackends
        )
        model.enrich(with: enrichedDetails)

        return model
    }

    /// Creates a mock DiscoveredModel with sample images for testing image functionality
    /// - Parameters:
    ///   - id: The model ID (defaults to "test-model-with-images")
    ///   - imageCount: Number of sample images to generate (defaults to 3)
    /// - Returns: A mock DiscoveredModel with populated image URLs
    public static func createMockWithImages(
        id: String = "test-model-with-images",
        imageCount: Int = 3
    ) -> DiscoveredModel {
        let sampleImages = (1...imageCount).map { index in
            "https://huggingface.co/\(id)/resolve/main/sample_\(index).png"
        }

        return createMock(
            id: id,
            modelCard: """
            # Model with Images

            ![Architecture](architecture.png)
            ![Sample Output](sample_1.png)
            ![Comparison](comparison.jpg)

            ## Features
            - Advanced architecture
            - High quality outputs
            """,
            imageUrls: sampleImages
        )
    }

    /// Creates a mock DiscoveredModel representing a converted model (no images)
    /// - Parameter originalModelId: ID of the original model this was converted from
    /// - Returns: A mock converted model
    public static func createMockConvertedModel(
        originalModelId: String = "original-org/original-model"
    ) -> DiscoveredModel {
        createMock(
            id: "mlx-community/converted-model",
            community: "mlx-community",
            tags: ["text-generation", "mlx", "converted"],
            modelCard: """
            # MLX Converted Model

            This model was converted from \(originalModelId) using the MLX framework.

            ## Usage
            Load with MLX for efficient inference on Apple Silicon.
            """,
            imageUrls: []
        )
    }
}
