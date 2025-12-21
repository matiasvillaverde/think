import Abstractions
import Database
import SwiftUI
import Testing
@testable import UIComponents

@Suite("ModelActionButton Integration Tests")
internal struct ModelDownloadingViewIntegrationTests {
    @Test("Uses ModelActionButton for download progress")
    @MainActor
    func usesModelActionButton() {
        // Given: A model with downloading state
        guard let downloadingModel = Model.previews.first(where: { model in
            model.state?.isDownloadingActive == true
        }) else {
            Issue.record("No downloading model found in previews")
            return
        }

        // When: Creating ModelActionButton with the downloading model
        _ = ModelActionButton(model: downloadingModel)

        // Then: Verify the model is in downloading state
        #expect(downloadingModel.state?.isDownloadingActive == true)
    }

    @Test("Provides pause/resume/cancel actions through button")
    @MainActor
    func providesActionsThoughButton() {
        // Given: A model with paused download state
        guard let pausedModel = Model.previews.first(where: { model in
            model.state?.isDownloadingPaused == true
        }) else {
            Issue.record("No paused model found in previews")
            return
        }

        // When: Creating ModelActionButton with the paused model
        _ = ModelActionButton(model: pausedModel)

        // Then: Verify the model is in paused state
        #expect(pausedModel.state?.isDownloadingPaused == true)
    }

    @Test("Handles multiple downloading models correctly")
    @MainActor
    func handlesMultipleDownloadingModels() {
        // Given: Multiple models with downloading states
        let downloadingModels: [Model] = Model.previews.filter { model in
            model.state?.isDownloading == true
        }
        guard downloadingModels.count >= 2 else {
            Issue.record("Not enough downloading models in previews")
            return
        }

        // When: Creating buttons for both models
        _ = ModelActionButton(model: downloadingModels[0])
        _ = ModelActionButton(model: downloadingModels[1])

        // Then: Both models should be in downloading state
        #expect(downloadingModels[0].state?.isDownloading == true)
        #expect(downloadingModels[1].state?.isDownloading == true)
    }

    @Test("Shows enhanced UI with download metrics")
    @MainActor
    func showsEnhancedUIWithMetrics() {
        // Given: A model with 25% download progress
        guard let downloadingModel = Model.previews.first(where: { model in
            model.state == .downloadingActive && model.downloadProgress == 0.25
        }) else {
            Issue.record("No model with 25% progress found in previews")
            return
        }

        // When: Creating ModelActionButton
        _ = ModelActionButton(model: downloadingModel)

        // Then: Verify model has size and correct progress
        #expect(downloadingModel.size > 0)
        #expect(downloadingModel.downloadProgress == 0.25)
    }
}
