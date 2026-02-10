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

            TextField(
                "",
                text: $searchQuery,
                prompt: Text("Search models...", bundle: .module)
            )
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
                        .accessibilityLabel(Text("Clear search", bundle: .module))
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
            sortByPicker
            directionPicker

            Spacer()
        }
    }

    private var sortByPicker: some View {
        Picker(selection: $selectedSort) {
            ForEach(SortOption.allCases, id: \.self) { option in
                Text(option.displayName).tag(option)
            }
        } label: {
            Text("Sort by", bundle: .module)
        }
        .pickerStyle(.menu)
        .onChange(of: selectedSort) { _, _ in
            if !searchQuery.isEmpty {
                onSearch()
            }
        }
    }

    private var directionPicker: some View {
        Picker(selection: $selectedDirection) {
            Image(systemName: "arrow.down")
                .accessibilityLabel(Text("Descending", bundle: .module))
                .tag(SortDirection.descending)
            Image(systemName: "arrow.up")
                .accessibilityLabel(Text("Ascending", bundle: .module))
                .tag(SortDirection.ascending)
        }
        label: {
            Text("Direction", bundle: .module)
        }
        .pickerStyle(.segmented)
        .frame(width: 100)
        .onChange(of: selectedDirection) { _, _ in
            if !searchQuery.isEmpty {
                onSearch()
            }
        }
    }
}
