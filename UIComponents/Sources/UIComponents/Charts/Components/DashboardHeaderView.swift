import Database
import SwiftUI

/// Header view for the dashboard displaying title and statistics
internal struct DashboardHeaderView: View {
    let allMetricsCount: Int
    let messagesWithMetricsCount: Int
    let activeModelsCount: Int
    let constants: HeaderConstants

    struct HeaderConstants {
        let headerIconSize: CGFloat
        let headerSpacing: CGFloat
    }

    var body: some View {
        HStack {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: constants.headerIconSize))
                .foregroundStyle(.indigo)
                .accessibilityLabel(Text("App dashboard icon", bundle: .module))

            VStack(alignment: .leading, spacing: constants.headerSpacing) {
                Text("Application Metrics", bundle: .module)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                headerStatistics
            }

            Spacer()
        }
    }

    private var headerStatistics: some View {
        HStack {
            Text("\(allMetricsCount) total metrics", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)

            if messagesWithMetricsCount > 0 {
                Text("•")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)

                Text("\(messagesWithMetricsCount) messages", bundle: .module)
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }

            if activeModelsCount > 0 {
                Text("•")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)

                Text("\(activeModelsCount) models", bundle: .module)
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }
        }
    }
}
