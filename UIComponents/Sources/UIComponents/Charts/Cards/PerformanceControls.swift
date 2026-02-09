import SwiftUI

internal struct PerformanceControls: View {
    @Binding var timeRange: PerformanceLineChart.TimeRange
    @Binding var autoRefresh: Bool
    @Binding var showCustomization: Bool
    @Binding var selectedMetrics: Set<PerformanceLineChart.PerformanceMetric>

    private enum Constants {
        static let maxPickerWidth: CGFloat = 200
        static let legendCircleSize: CGFloat = 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ChartConstants.Layout.cardSpacing) {
            compactControls

            if showCustomization {
                Divider()
                expandedControls
            }
        }
    }

    private var compactControls: some View {
        HStack {
            Picker("Range", selection: $timeRange) {
                ForEach(PerformanceLineChart.TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: Constants.maxPickerWidth)

            Spacer()

            Toggle("Auto", isOn: $autoRefresh)
                .toggleStyle(.switch)
                .fixedSize()

            Button {
                withAnimation {
                    showCustomization.toggle()
                }
            } label: {
                Image(systemName: showCustomization ? "gearshape.fill" : "gearshape")
                    .foregroundColor(.accentColor)
                    .accessibilityLabel("Customization settings")
            }
            .buttonStyle(.plain)
        }
    }

    private var expandedControls: some View {
        VStack(alignment: .leading, spacing: ChartConstants.Layout.itemSpacing) {
            Text("Visible Metrics")
                .font(.caption)
                .foregroundColor(Color.textSecondary)

            ForEach(PerformanceLineChart.PerformanceMetric.allCases) { metric in
                Toggle(isOn: Binding(
                    get: { selectedMetrics.contains(metric) },
                    set: { isOn in
                        if isOn {
                            selectedMetrics.insert(metric)
                        } else {
                            selectedMetrics.remove(metric)
                        }
                    }
                )) {
                    HStack {
                        Circle()
                            .fill(metric.color)
                            .frame(
                                width: Constants.legendCircleSize,
                                height: Constants.legendCircleSize
                            )
                        Text(metric.rawValue)
                            .font(.subheadline)
                    }
                }
            }
        }
    }
}
