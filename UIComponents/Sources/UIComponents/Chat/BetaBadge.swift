import SwiftUI

public struct BetaBadge: View {
    private enum Constants {
        static let paddingH: CGFloat = 6
        static let paddingV: CGFloat = 2
    }

    public var body: some View {
        Text(
            "ßETA",
            bundle: .module,
            comment: "Label telling that the app is in beta version. Use ß when possible"
        )
        .font(.caption)
        .bold()
        .padding(.horizontal, Constants.paddingH)
        .padding(.vertical, Constants.paddingV)
        .background(
            Capsule()
                .fill(Color.marketingSecondary)
        )
        .foregroundColor(.white)
    }
}

#Preview {
    BetaBadge()
}
