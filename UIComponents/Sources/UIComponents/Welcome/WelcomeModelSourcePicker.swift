import SwiftUI

internal struct WelcomeModelSourcePicker: View {
    private enum Constants {
        static let tabSpacing: CGFloat = 10
        static let horizontalPadding: CGFloat = 16
        static let tabPaddingHorizontal: CGFloat = 12
        static let tabPaddingVertical: CGFloat = 8
        static let borderWidth: CGFloat = 1
        static let selectedStrokeOpacity: Double = 0.35
        static let unselectedStrokeOpacity: Double = 0.16
    }

    @Binding var selectedSource: WelcomeView.ModelSource

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Constants.tabSpacing) {
                ForEach(WelcomeView.ModelSource.allCases) { source in
                    tab(source)
                }
            }
            .padding(.horizontal, Constants.horizontalPadding)
        }
        .accessibilityLabel(Text(String(localized: "Model Source", bundle: .module)))
    }

    private func tab(_ source: WelcomeView.ModelSource) -> some View {
        let isSelected: Bool = selectedSource == source
        return Button {
            selectedSource = source
        } label: {
            Text(source.title)
                .font(.callout)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                .padding(.horizontal, Constants.tabPaddingHorizontal)
                .padding(.vertical, Constants.tabPaddingVertical)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.backgroundSecondary : Color.paletteClear)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                                ? Color.marketingPrimary.opacity(Constants.selectedStrokeOpacity)
                                : Color.textSecondary.opacity(Constants.unselectedStrokeOpacity),
                            lineWidth: Constants.borderWidth
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    WelcomeModelSourcePicker(selectedSource: .constant(.local))
        .padding()
}
#endif
