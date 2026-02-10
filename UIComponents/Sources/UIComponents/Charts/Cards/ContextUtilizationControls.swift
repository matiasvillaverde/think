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
                Text("Capacity:", bundle: .module)
                    .font(.subheadline)
                    .foregroundColor(Color.textSecondary)

                Spacer()

                Picker(selection: $contextCapacity) {
                    ForEach(capacityOptions, id: \.self) { capacity in
                        Text("\(capacity) tokens", bundle: .module).tag(capacity)
                    }
                } label: {
                    Text("Context Capacity", bundle: .module)
                }
                .pickerStyle(.menu)
            }

            // View options
            VStack(spacing: ChartConstants.Layout.itemSpacing) {
                Toggle(isOn: $showFillArea) {
                    Text("Show fill area", bundle: .module)
                }
                .font(.subheadline)

                Toggle(isOn: $showDataPoints) {
                    Text("Show data points", bundle: .module)
                }
                .font(.subheadline)
            }
        }
    }
}
