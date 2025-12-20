import SwiftUI

// MARK: - Token Probability Supporting Types

public enum TokenType: String, CaseIterable {
    case all = "All Tokens"
    case highProb = "High Probability"
    case lowProb = "Low Probability"
    case uncertain = "Uncertain"

    func filter(_ probability: Double, highThreshold: Double, lowThreshold: Double) -> Bool {
        switch self {
        case .all:
            true

        case .highProb:
            probability > highThreshold

        case .lowProb:
            probability < lowThreshold

        case .uncertain:
            probability >= lowThreshold && probability <= highThreshold
        }
    }
}

internal struct TokenProbability: Identifiable {
    let id: UUID = .init()
    let tokenIndex: Int
    let probability: Double
    let tokenLength: Int
    let metricId: String
    let color: Color
}
