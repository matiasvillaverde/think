import SwiftUI

internal struct PerplexityHeatMapControls: View {
    @Binding var colorScheme: HeatMapColorScheme
    @Binding var showLabels: Bool

    var body: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            colorSchemePicker
            showLabelsToggle
        }
    }

    private var colorSchemePicker: some View {
        HStack {
            Text("Color Scheme:", bundle: .module)
                .font(.subheadline)
                .foregroundColor(Color.textSecondary)

            Spacer()

            Picker(selection: $colorScheme) {
                ForEach(HeatMapColorScheme.allCases, id: \.self) { scheme in
                    Text(scheme.displayName).tag(scheme)
                }
            } label: {
                Text("Color Scheme", bundle: .module)
            }
            .pickerStyle(.menu)
        }
    }

    private var showLabelsToggle: some View {
        Toggle(isOn: $showLabels) {
            Text("Show values", bundle: .module)
        }
        .font(.subheadline)
    }
}
