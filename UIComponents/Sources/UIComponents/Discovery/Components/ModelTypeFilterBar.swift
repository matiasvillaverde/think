import SwiftUI

/// A segmented control filter bar for model types with icons
internal struct ModelTypeFilterBar: View {
    // MARK: - Properties

    @Binding var selection: ModelTypeFilter

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ModelTypeFilter.allCases) { filter in
                filterButton(for: filter)

                if filter != ModelTypeFilter.allCases.last {
                    Divider()
                        .frame(height: DiscoveryConstants.FilterBar.dividerHeight)
                        .opacity(DiscoveryConstants.FilterBar.dividerOpacity)
                }
            }
        }
        .background(Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Radius.standard))
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.Radius.standard)
                .stroke(
                    Color.textSecondary.opacity(DiscoveryConstants.FilterBar.borderOpacity),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, DesignConstants.Spacing.large)
    }

    // MARK: - Subviews

    private func filterButton(for filter: ModelTypeFilter) -> some View {
        Button(action: {
            withAnimation(.smooth) {
                selection = filter
            }
        }, label: {
            HStack(spacing: DesignConstants.Spacing.small) {
                Image(systemName: filter.iconName)
                    .font(.caption)
                    .foregroundColor(selection == filter ? .textPrimary : .textSecondary)

                Text(filter.displayName)
                    .font(.caption)
                    .foregroundColor(selection == filter ? .textPrimary : .textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignConstants.Spacing.large)
            .background(
                selection == filter
                    ? Color.backgroundPrimary
                    : Color.clear
            )
        })
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == filter ? [.isSelected] : [])
        .accessibilityLabel("\(filter.displayName) filter")
        .accessibilityHint(
            selection == filter
                ? "Currently selected"
                : "Tap to filter by \(filter.displayName)"
        )
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Filter Bar") {
        @Previewable @State var selection: ModelTypeFilter = .text

        VStack(spacing: DesignConstants.Spacing.large) {
            ModelTypeFilterBar(selection: $selection)

            Text("Selected: \(selection.displayName)")
                .font(.caption)
                .foregroundColor(.textSecondary)
                .padding()

            Spacer()
        }
        .background(Color.backgroundPrimary)
    }

    #Preview("All States") {
        VStack(spacing: DesignConstants.Spacing.huge) {
            ForEach(ModelTypeFilter.allCases) { filter in
                VStack(alignment: .leading) {
                    Text("Selection: \(filter.displayName)")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal)

                    ModelTypeFilterBar(selection: .constant(filter))
                }
            }
        }
        .background(Color.backgroundPrimary)
    }
#endif
