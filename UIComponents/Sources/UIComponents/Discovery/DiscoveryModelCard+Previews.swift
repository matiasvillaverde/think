#if DEBUG
    import Abstractions
    import SwiftUI

    #Preview("Single Card") {
        let model: DiscoveredModel = DiscoveredModel(
            id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            name: "Llama-3.2-3B-Instruct-4bit",
            author: "mlx-community",
            downloads: DiscoveryConstants.PreviewData.previewDownloads7,
            likes: DiscoveryConstants.PreviewData.previewLikes7,
            tags: ["text-generation", "llama", "conversational"],
            lastModified: Date(),
            files: [],
            license: "llama3.2",
            licenseUrl: "https://llama.meta.com/llama3_2/license/",
            metadata: [:]
        )

        let enrichedDetails: EnrichedModelDetails = EnrichedModelDetails(
            modelCard: nil,
            cardData: nil,
            imageUrls: ["https://picsum.photos/400/225"],
            detectedBackends: [.mlx]
        )
        model.enrich(with: enrichedDetails)

        return DiscoveryModelCard(model: model)
            .padding()
    }

    #Preview("Multiple Cards") {
        let models: [DiscoveredModel] = createPreviewModels()

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignConstants.Spacing.large) {
                ForEach(models) { model in
                    DiscoveryModelCard(model: model)
                }
            }
            .padding()
        }
    }

    @MainActor
    private func createPreviewModels() -> [DiscoveredModel] {
        let previewModelCount: Int = 3
        let baseDownloads: Int = 1_000
        let baseLikes: Int = 100
        let incrementStep: Int = 1
        return (0 ..< previewModelCount).map { index in
            let model: DiscoveredModel = DiscoveredModel(
                id: "model-\(index)",
                name: "Model \(index)",
                author: "author-\(index)",
                downloads: baseDownloads * (index + incrementStep),
                likes: baseLikes * (index + incrementStep),
                tags: ["text-generation"],
                lastModified: Date(),
                files: [],
                license: nil,
                licenseUrl: nil,
                metadata: [:]
            )

            let enrichedDetails: EnrichedModelDetails = EnrichedModelDetails(
                modelCard: nil,
                cardData: nil,
                imageUrls: [],
                detectedBackends: [.mlx]
            )
            model.enrich(with: enrichedDetails)

            return model
        }
    }
#endif
