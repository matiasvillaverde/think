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
            Text("Color Scheme:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Picker("Color Scheme", selection: $colorScheme) {
                ForEach(HeatMapColorScheme.allCases, id: \.self) { scheme in
                    Text(scheme.rawValue).tag(scheme)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var showLabelsToggle: some View {
        Toggle("Show values", isOn: $showLabels)
            .font(.subheadline)
    }
}
