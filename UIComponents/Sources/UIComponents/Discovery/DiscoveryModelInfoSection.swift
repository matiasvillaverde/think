import Abstractions
import SwiftUI

// MARK: - Model Info Section

internal struct DiscoveryModelInfoSection: View {
    let model: DiscoveredModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.medium) {
            Text("Model Information", bundle: .module)
                .font(.headline)
                .foregroundColor(.textPrimary)

            VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
                if let modelType = model.inferredModelType {
                    infoRow(label: "Type", value: displayName(for: modelType))
                }
                infoRow(label: "Downloads", value: formatNumber(model.downloads))
                infoRow(label: "Likes", value: formatNumber(model.likes))
                infoRow(label: "Last Updated", value: formatDate(model.lastModified))
                infoRow(label: "Repository", value: model.id)
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, DesignConstants.Spacing.xSmall)
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter: NumberFormatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(for: number) ?? "\(number)"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func displayName(for type: SendableModel.ModelType) -> String {
        switch type {
        case .language, .deepLanguage, .flexibleThinker:
            String(localized: "Language Model", bundle: .module)

        case .diffusion, .diffusionXL:
            String(localized: "Image Generation", bundle: .module)

        case .visualLanguage:
            String(localized: "Vision Language Model", bundle: .module)
        }
    }
}
