import SwiftUI

/// A view displayed when chart data is empty
public struct EmptyChartView: View {
    let message: String

    private enum Constants {
        static let iconSize: CGFloat = 48
        static let spacing: CGFloat = 16
        static let cornerRadius: CGFloat = 12
        static let minHeight: CGFloat = 200
    }

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: Constants.spacing) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: Constants.iconSize))
                .foregroundColor(.secondary)
                .accessibilityLabel("Empty chart icon")

            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: Constants.minHeight)
        .background(.quaternary)
        .cornerRadius(Constants.cornerRadius)
    }
}

#if false // DEBUG
    #Preview {
        EmptyChartView(message: "No data available")
            .padding()
    }
#endif
