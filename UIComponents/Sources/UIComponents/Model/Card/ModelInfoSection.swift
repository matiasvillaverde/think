import Abstractions
import Database
import SwiftUI

internal struct ModelInfoSection: View {
    @Bindable var model: Model
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.medium) {
            HStack {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.marketingSecondary)
                        .accessibilityLabel(
                            String(
                                localized: "Selected model",
                                bundle: .module,
                                comment: "Accessibility label for the selected model"
                            )
                        )
                        .font(.body)
                        .bold()
                }
                Text(model.displayName)
                    .font(.title2)
                    .bold()
                    .foregroundColor(Color.textPrimary)
                Spacer()
            }

            Text(model.displayDescription)
                .font(.footnote)
                .foregroundColor(Color.textSecondary)
                .lineLimit(DesignConstants.Spacing.lineCount)

            HStack(spacing: DesignConstants.Spacing.standard) {
                ModelSpec(
                    value: formatRAM(Int(model.ramNeeded))
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    private func formatRAM(_ bytes: Int) -> String {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useGB]
        formatter.includesUnit = true
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#if DEBUG
    #Preview {
        @Previewable @State var models: [Model] = Model.previews
        List(models) { model in
            ModelInfoSection(model: model, isSelected: true)
        }
    }
#endif
