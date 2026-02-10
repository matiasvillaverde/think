import SwiftUI

/// An interactive search bar that opens HuggingFace search
internal struct DiscoverySearchBar: View {
    // MARK: - State

    @State private var showingSearchView: Bool = false

    // MARK: - Body

    var body: some View {
        Button {
            showingSearchView = true
        } label: {
            HStack(spacing: DesignConstants.Spacing.medium) {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .accessibilityHidden(true)

                Text("Search HuggingFace models...", bundle: .module)
                    .font(.body)
                    .foregroundColor(.textSecondary)

                Spacer()

                Image(systemName: "arrow.forward.circle")
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DesignConstants.Spacing.large)
            .padding(.vertical, DesignConstants.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.Radius.standard)
                    .fill(Color.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.Radius.standard)
                    .stroke(
                        Color.textSecondary.opacity(DesignConstants.Opacity.line),
                        lineWidth: DesignConstants.Line.thin
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSearchView) {
            HuggingFaceSearchView()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: DesignConstants.Spacing.large) {
        DiscoverySearchBar()
            .padding()

        Text("Search functionality coming soon", bundle: .module)
            .font(.caption)
            .foregroundColor(.textSecondary)
    }
    .background(Color.backgroundPrimary)
}
#endif
