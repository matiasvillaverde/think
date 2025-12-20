import SwiftUI

// MARK: - Processing Time Supporting Types

public enum ProcessingSortOrder: String, CaseIterable {
    case byInference = "Inference"
    case byPostProcessing = "Post-Processing"
    case byTokenization = "Tokenization"
    case byTotal = "Total Time"
}

internal struct ProcessingStage: Identifiable {
    let id: UUID = .init()
    let metricId: String
    let stage: String
    let duration: Double
    let percentage: Double
    let color: Color
}
