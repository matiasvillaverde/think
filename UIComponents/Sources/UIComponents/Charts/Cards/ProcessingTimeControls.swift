import SwiftUI

internal struct ProcessingTimeControls: View {
    @Binding var sortOrder: ProcessingSortOrder
    @Binding var showPercentages: Bool
    @Binding var maxItems: Int
    let maxItemsLimit: Int
    let minItems: Int

    var body: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            sortOrderPicker
            maxItemsSlider
            showPercentagesToggle
        }
    }

    private var sortOrderPicker: some View {
        HStack {
            Text("Sort:")
                .font(.subheadline)
                .foregroundColor(Color.textSecondary)

            Spacer()

            Picker("Sort Order", selection: $sortOrder) {
                ForEach(ProcessingSortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var maxItemsSlider: some View {
        VStack(alignment: .leading, spacing: ChartConstants.Layout.itemSpacing) {
            HStack {
                Text("Show:")
                    .font(.subheadline)
                    .foregroundColor(Color.textSecondary)

                Text("\(maxItems) metrics")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.textPrimary)

                Spacer()
            }

            Slider(
                value: Binding(
                    get: { Double(maxItems) },
                    set: { maxItems = Int($0) }
                ),
                in: Double(minItems) ... Double(maxItemsLimit),
                step: 1
            )
        }
    }

    private var showPercentagesToggle: some View {
        Toggle("Show percentages", isOn: $showPercentages)
            .font(.subheadline)
    }
}
