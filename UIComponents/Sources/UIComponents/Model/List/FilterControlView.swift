import SwiftUI

// MARK: - Filter Control View

internal struct FilterControlView: View {
    @Binding private var filterMode: FilterMode

    init(filterMode: Binding<FilterMode>) {
        _filterMode = filterMode
    }

    var body: some View {
        Picker(String(localized: "Filter", bundle: .module), selection: $filterMode) {
            Label {
                Text(
                    "Recommended",
                    bundle: .module,
                    comment: "Filter mode label"
                )
            } icon: {
                Image(systemName: "star.fill")
                    .font(.callout)
                    .foregroundColor(Color.marketingPrimary)
                    .accessibilityLabel(
                        String(
                            localized: "Recommended models",
                            bundle: .module,
                            comment: "Accessibility label for the recommended filter mode icon"
                        )
                    )
            }
            .tag(FilterMode.recommended)
            Text(
                "Selected",
                bundle: .module,
                comment: "Filter mode label"
            ).tag(FilterMode.selected)
            Text(
                "All",
                bundle: .module,
                comment: "Filter mode label"
            ).tag(FilterMode.all)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal, DesignConstants.Spacing.large)
        .padding(.top, DesignConstants.Spacing.huge)
    }
}
