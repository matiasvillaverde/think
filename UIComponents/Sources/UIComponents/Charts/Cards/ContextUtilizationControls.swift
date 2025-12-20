import SwiftUI

internal struct ContextUtilizationControls: View {
    @Binding var showFillArea: Bool
    @Binding var showDataPoints: Bool
    @Binding var contextCapacity: Int
    let capacityOptions: [Int]

    var body: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            // Capacity selector
            HStack {
                Text("Capacity:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Picker("Context Capacity", selection: $contextCapacity) {
                    ForEach(capacityOptions, id: \.self) { capacity in
                        Text("\(capacity) tokens").tag(capacity)
                    }
                }
                .pickerStyle(.menu)
            }

            // View options
            VStack(spacing: ChartConstants.Layout.itemSpacing) {
                Toggle("Show fill area", isOn: $showFillArea)
                    .font(.subheadline)

                Toggle("Show data points", isOn: $showDataPoints)
                    .font(.subheadline)
            }
        }
    }
}
