import Abstractions
import Database
import SwiftUI

// MARK: - Previews

#if DEBUG
    #Preview("Model States") {
        VStack(spacing: 20) {
            ForEach(Model.previews.prefix(5)) { model in
                HStack {
                    Text(model.displayName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ModelActionButton(model: model)
                }
                .padding()
            }
        }
    }

    #Preview("Discovered Model") {
        let discoveredModel: DiscoveredModel = DiscoveredModel(
            id: "test/model",
            name: "Test Model",
            author: "test",
            downloads: 100,
            likes: 10,
            tags: ["test"],
            lastModified: Date(),
            files: [],
            license: "MIT",
            licenseUrl: nil
        )

        HStack {
            Text("Test Model")
                .frame(maxWidth: .infinity, alignment: .leading)
            ModelActionButton(discoveredModel: discoveredModel)
        }
        .padding()
    }
#endif
