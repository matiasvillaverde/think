import SwiftUI

internal struct TokenProbabilityControls: View {
    @Binding var selectedTokenType: TokenType
    @Binding var showTrendLine: Bool
    @Binding var showConfidenceBands: Bool

    var body: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            tokenTypePicker
            trendLineToggle
            confidenceBandsToggle
        }
    }

    private var tokenTypePicker: some View {
        HStack {
            Text("Token Type:")
                .font(.subheadline)
                .foregroundColor(Color.textSecondary)

            Spacer()

            Picker("Token Type", selection: $selectedTokenType) {
                ForEach(TokenType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var trendLineToggle: some View {
        Toggle("Show trend line", isOn: $showTrendLine)
            .font(.subheadline)
    }

    private var confidenceBandsToggle: some View {
        Toggle("Show confidence bands", isOn: $showConfidenceBands)
            .font(.subheadline)
    }
}
