import Abstractions
import Database
import SwiftUI

// MARK: - Styling

extension ChannelMessageView {
    internal var channelIcon: some View {
        Image(systemName: channelIconName)
            .accessibilityHidden(true)
    }

    internal var channelIconName: String {
        switch channel.type {
        case .analysis:
            return "brain.head.profile"

        case .commentary:
            return "bubble.left.and.text.bubble.right"

        case .final:
            return "text.bubble"

        case .tool:
            return "wrench.and.screwdriver"
        }
    }

    internal var channelColor: Color {
        switch channel.type {
        case .analysis:
            return .textSecondary

        case .commentary:
            return .textPrimary

        case .final:
            return .textPrimary

        case .tool:
            return .orange
        }
    }

    internal var contentFont: Font {
        switch channel.type {
        case .analysis:
            return .system(
                size: Constants.analysisFontSize,
                weight: .medium,
                design: .monospaced
            )

        case .commentary:
            return .footnote

        case .final:
            return .body

        case .tool:
            return .caption
        }
    }

    internal var contentColor: Color {
        switch channel.type {
        case .analysis:
            return .textSecondary

        case .commentary:
            return .textPrimary

        case .final:
            return .textPrimary

        case .tool:
            return .orange
        }
    }

    internal var backgroundColor: Color {
        switch channel.type {
        case .analysis:
            return .backgroundSecondary.opacity(Constants.analysisOpacity)

        case .commentary:
            return .clear

        case .final:
            return .clear

        case .tool:
            let opacity: Double = 0.1
            return .orange.opacity(opacity)
        }
    }

    internal var contentPadding: EdgeInsets {
        switch channel.type {
        case .analysis, .commentary, .tool:
            let padding: CGFloat = Constants.contentPadding
            return EdgeInsets(
                top: padding,
                leading: padding,
                bottom: padding,
                trailing: padding
            )

        case .final:
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        }
    }
}
