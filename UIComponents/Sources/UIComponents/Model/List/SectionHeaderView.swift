import SwiftUI

// MARK: - Section Header View

internal struct SectionHeaderView: View {
    private let title: String

    init(title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.title)
            .bold()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignConstants.Spacing.standard)
            .padding(.top, DesignConstants.Spacing.standard)
    }
}
