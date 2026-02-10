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
            Text("Time Range:", bundle: .module)
                .font(.subheadline)
                .foregroundColor(Color.textSecondary)

            Spacer()

            Picker(selection: $timeRange) {
                ForEach(MemoryTimeRange.allCases, id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            } label: {
                Text("Time Range", bundle: .module)
            }
            .pickerStyle(.segmented)
        }
    }

    private var memoryToggles: some View {
        VStack(spacing: Constants.toggleSpacing) {
            Toggle(isOn: $showPeakMemory) {
                Text("Show peak memory", bundle: .module)
            }
            .font(.subheadline)

            Toggle(isOn: $showActiveMemory) {
                Text("Show active memory", bundle: .module)
            }
            .font(.subheadline)
        }
    }
}
