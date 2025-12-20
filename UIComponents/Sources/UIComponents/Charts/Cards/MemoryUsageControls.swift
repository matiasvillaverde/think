import SwiftUI

internal struct MemoryUsageControls: View {
    @Binding var timeRange: MemoryTimeRange
    @Binding var showPeakMemory: Bool
    @Binding var showActiveMemory: Bool

    private enum Constants {
        static let toggleSpacing: CGFloat = 8
    }

    var body: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            timeRangePicker
            memoryToggles
        }
    }

    private var timeRangePicker: some View {
        HStack {
            Text("Time Range:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Picker("Time Range", selection: $timeRange) {
                ForEach(MemoryTimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var memoryToggles: some View {
        VStack(spacing: Constants.toggleSpacing) {
            Toggle("Show peak memory", isOn: $showPeakMemory)
                .font(.subheadline)

            Toggle("Show active memory", isOn: $showActiveMemory)
                .font(.subheadline)
        }
    }
}
