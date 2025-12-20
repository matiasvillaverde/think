import SwiftUI

// MARK: - Explore Agents Row View

internal struct ExplorePersonalitiesRowView: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PersonalityLayout.rowSpacing) {
                Image(systemName: "square.grid.2x2")
                    .font(
                        .system(
                            size: PersonalityLayout.exploreIconImageSize,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(Color.textPrimary)

                Text("Explore Personalities", bundle: .module)
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, PersonalityLayout.rowVerticalPadding)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Explore Agents", bundle: .module))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    ExplorePersonalitiesRowView {
        print("Tapped")
    }
}
