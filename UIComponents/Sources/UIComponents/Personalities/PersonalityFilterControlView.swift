// PersonalityFilterControlView.swift
import SwiftUI

/// Control view for filtering personalities by category
internal struct PersonalityFilterControlView: View {
    @Binding var filterMode: PersonalityFilterMode

    private enum Layout {
        static let opacity: Double = 0.1
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignConstants.Spacing.medium) {
                ForEach(PersonalityFilterMode.allCases, id: \.self) { mode in
                    FilterButton(
                        title: mode.displayName,
                        isSelected: filterMode == mode
                    ) {
                        withAnimation {
                            filterMode = mode
                        }
                    }
                }
            }
            .padding(.horizontal, DesignConstants.Spacing.large)
        }
    }

    private struct FilterButton: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(title)
                    .fontWeight(isSelected ? .bold : .regular)
                    .padding(.vertical, DesignConstants.Spacing.small)
                    .padding(.horizontal, DesignConstants.Spacing.medium)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.accentColor
                                : Color.backgroundSecondary.opacity(Layout.opacity))
                    )
                    .foregroundColor(isSelected ? .white : .textPrimary)
            }
        }
    }
}
