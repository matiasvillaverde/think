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
            Text("N-gram level:", bundle: .module)
                .font(.subheadline)
                .foregroundColor(Color.textSecondary)

            Spacer()

            Picker(selection: $selectedNGram) {
                ForEach(NGramLevel.allCases, id: \.self) { level in
                    Text(verbatim: level.rawValue).tag(level)
                }
            } label: {
                Text("N-gram", bundle: .module)
            }
            .pickerStyle(.segmented)
        }
    }

    private var viewToggles: some View {
        VStack(spacing: Constants.controlSpacing) {
            Toggle(isOn: $showTrend) {
                Text("Show trend area", bundle: .module)
            }
            .font(.subheadline)

            Toggle(isOn: $showBaseline) {
                Text("Show baselines", bundle: .module)
            }
            .font(.subheadline)
        }
    }
}
