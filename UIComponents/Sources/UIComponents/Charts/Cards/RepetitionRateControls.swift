import SwiftUI

internal struct RepetitionRateControls: View {
    @Binding var selectedNGram: NGramLevel
    @Binding var showTrend: Bool
    @Binding var showBaseline: Bool

    private enum Constants {
        static let controlSpacing: CGFloat = 8
    }

    var body: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            nGramSelector
            viewToggles
        }
    }

    private var nGramSelector: some View {
        HStack {
            Text("N-gram level:")
                .font(.subheadline)
                .foregroundColor(Color.textSecondary)

            Spacer()

            Picker("N-gram", selection: $selectedNGram) {
                ForEach(NGramLevel.allCases, id: \.self) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var viewToggles: some View {
        VStack(spacing: Constants.controlSpacing) {
            Toggle("Show trend area", isOn: $showTrend)
                .font(.subheadline)

            Toggle("Show baselines", isOn: $showBaseline)
                .font(.subheadline)
        }
    }
}
