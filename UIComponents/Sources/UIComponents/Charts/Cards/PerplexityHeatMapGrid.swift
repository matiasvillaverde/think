import SwiftUI

internal struct PerplexityHeatMapGrid: View {
    let heatMapData: [[HeatMapCell]]
    let colorScheme: HeatMapColorScheme
    let showLabels: Bool
    @Binding var selectedCell: HeatMapCell?
    let dataHasAppeared: Bool
    let viewModel: PerplexityHeatMapViewModel

    private enum Constants {
        static let cellSize: CGFloat = 30
        static let cellSpacing: CGFloat = 2
        static let cornerRadius: CGFloat = 4
        static let labelFontSize: CGFloat = 10
        static let selectedCellBorderWidth: CGFloat = 2
        static let springResponse: Double = 0.5
        static let dampingFraction: Double = 0.7
        static let cellAnimationDelay: Double = 0.02
        static let halfScale: Double = 0.5
    }

    var body: some View {
        VStack(spacing: Constants.cellSpacing) {
            ForEach(Array(heatMapData.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: Constants.cellSpacing) {
                    ForEach(row) { cell in
                        cellView(for: cell, rowIndex: rowIndex)
                    }
                }
            }
        }
    }

    private func cellView(for cell: HeatMapCell, rowIndex: Int) -> some View {
        RoundedRectangle(cornerRadius: Constants.cornerRadius)
            .fill(viewModel.colorForValue(cell.value, scheme: colorScheme))
            .frame(width: Constants.cellSize, height: Constants.cellSize)
            .overlay(
                Group {
                    if showLabels {
                        Text(cell.label)
                            .font(.system(size: Constants.labelFontSize))
                            .foregroundColor(.white)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .stroke(
                        selectedCell?.id == cell.id ? Color.paletteWhite : Color.paletteClear,
                        lineWidth: Constants.selectedCellBorderWidth
                    )
            )
            .scaleEffect(dataHasAppeared ? 1 : Constants.halfScale)
            .opacity(dataHasAppeared ? 1 : 0)
            .animation(
                .spring(
                    response: Constants.springResponse,
                    dampingFraction: Constants.dampingFraction
                )
                .delay(
                    Double(rowIndex * heatMapData[rowIndex].count + cell.column) *
                    Constants.cellAnimationDelay
                ),
                value: dataHasAppeared
            )
            .onTapGesture {
                withAnimation(.easeInOut) {
                    selectedCell = selectedCell?.id == cell.id ? nil : cell
                }
            }
            .accessibilityAddTraits(.isButton)
    }
}
