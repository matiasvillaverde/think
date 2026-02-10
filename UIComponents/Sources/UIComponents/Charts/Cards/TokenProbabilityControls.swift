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
            Text("Token Type:", bundle: .module)
                .font(.subheadline)
                .foregroundColor(Color.textSecondary)

            Spacer()

            Picker(selection: $selectedTokenType) {
                ForEach(TokenType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                Text("Token Type", bundle: .module)
            }
            .pickerStyle(.menu)
        }
    }

    private var trendLineToggle: some View {
        Toggle(isOn: $showTrendLine) {
            Text("Show trend line", bundle: .module)
        }
        .font(.subheadline)
    }

    private var confidenceBandsToggle: some View {
        Toggle(isOn: $showConfidenceBands) {
            Text("Show confidence bands", bundle: .module)
        }
        .font(.subheadline)
    }
}
