import Charts
import SwiftUI

internal struct MemoryUsageChart: View {
    let memoryData: [MemoryData]
    let showPeakMemory: Bool
    let showActiveMemory: Bool
    let dataHasAppeared: Bool
    let viewModel: MemoryUsageViewModel
    let chartHeight: CGFloat

    private enum Constants {
        static let barWidth: CGFloat = 20
        static let peakOpacity: Double = 0.7
        static let chartBackgroundOpacity: Double = 0.05
        static let borderOpacity: Double = 0.2
        static let borderWidth: CGFloat = 0.5
        static let fullOpacity: Double = 1
        static let dimmedOpacity: Double = 0.3
        static let animationDuration: Double = 0.7
        static let cornerRadius: CGFloat = 4
    }

    var body: some View {
        Chart(memoryData) { data in
            if showActiveMemory {
                BarMark(
                    x: .value("Index", data.index),
                    y: .value("Active", dataHasAppeared ? data.activeMemory : 0)
                )
                .foregroundStyle(.blue)
                .cornerRadius(Constants.cornerRadius)
                .opacity(showPeakMemory ? Constants.fullOpacity : Constants.fullOpacity)
            }

            if showPeakMemory {
                BarMark(
                    x: .value("Index", data.index),
                    y: .value("Peak", dataHasAppeared ? data.peakMemory : 0)
                )
                .foregroundStyle(.red.opacity(Constants.peakOpacity))
                .cornerRadius(Constants.cornerRadius)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
                AxisTick()
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let memory = value.as(Double.self) {
                        Text(viewModel.formatMemory(memory))
                    }
                }
                AxisGridLine()
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.gray.opacity(Constants.chartBackgroundOpacity))
                .border(
                    Color.gray.opacity(Constants.borderOpacity),
                    width: Constants.borderWidth
                )
        }
        .frame(height: chartHeight)
        .animation(.easeInOut(duration: Constants.animationDuration), value: dataHasAppeared)
        .animation(.easeInOut, value: showPeakMemory)
        .animation(.easeInOut, value: showActiveMemory)
    }
}
