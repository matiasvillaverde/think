import Abstractions
import SwiftUI

/// Header view for HuggingFace search with search field and sorting options
internal struct HuggingFaceSearchHeader: View {
    // MARK: - Bindings

    @Binding var searchQuery: String
    @Binding var selectedSort: SortOption
    @Binding var selectedDirection: SortDirection

    // MARK: - Callbacks

    let onSearch: () -> Void
    let onClear: () -> Void

    // MARK: - Body

    internal var body: some View {
        VStack(spacing: DesignConstants.Spacing.medium) {
            searchField
            sortOptions
        }
    }

    // MARK: - Subviews

    private var searchField: some View {
        HStack(spacing: DesignConstants.Spacing.medium) {
            Image(systemName: "magnifyingglass")
                .font(.body)
                .foregroundColor(.textSecondary)
                .accessibilityHidden(true)

            TextField("Search models...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.body)
                .submitLabel(.search)
                .onSubmit {
                    onSearch()
                }

            if !searchQuery.isEmpty {
                Button {
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondary)
                        .accessibilityLabel("Clear search")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignConstants.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignConstants.Radius.standard)
                .fill(Color.backgroundSecondary)
        )
    }

    private var sortOptions: some View {
        HStack(spacing: DesignConstants.Spacing.medium) {
            Picker("Sort by", selection: $selectedSort) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedSort) { _, _ in
                if !searchQuery.isEmpty {
                    onSearch()
                }
            }

            Picker("Direction", selection: $selectedDirection) {
                Image(systemName: "arrow.down")
                    .accessibilityLabel("Descending")
                    .tag(SortDirection.descending)
                Image(systemName: "arrow.up")
                    .accessibilityLabel("Ascending")
                    .tag(SortDirection.ascending)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
            .onChange(of: selectedDirection) { _, _ in
                if !searchQuery.isEmpty {
                    onSearch()
                }
            }

            Spacer()
        }
    }
}
