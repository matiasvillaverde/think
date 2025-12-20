import SwiftUI

/// A view that displays time range selection buttons
internal struct TimeRangeSelectorView: View {
    @Binding var selectedTimeRange: AppWideDashboard.TimeRange
    let constants: TimeRangeSelectorConstants

    struct TimeRangeSelectorConstants {
        let spacing: CGFloat
        let cardPadding: CGFloat
        let dividerPadding: CGFloat
        let cornerRadius: CGFloat
        let selectedOpacity: Double
        let unselectedOpacity: Double
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: constants.spacing) {
                ForEach(AppWideDashboard.TimeRange.allCases, id: \.self) { range in
                    Button {
                        selectedTimeRange = range
                    } label: {
                        Label(range.rawValue, systemImage: range.icon)
                            .font(.subheadline)
                            .padding(.horizontal, constants.cardPadding)
                            .padding(.vertical, constants.dividerPadding)
                            .background(
                                selectedTimeRange == range ?
                                    Color.accentColor.opacity(constants.selectedOpacity) :
                                    Color.secondary.opacity(constants.unselectedOpacity)
                            )
                            .foregroundColor(
                                selectedTimeRange == range ?
                                    Color.accentColor :
                                    Color.primary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: constants.cornerRadius))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
