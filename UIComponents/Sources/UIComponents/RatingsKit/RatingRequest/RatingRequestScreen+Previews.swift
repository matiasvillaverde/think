import OSLog
import SwiftUI

private let kPreviewLogger: Logger = Logger(
    subsystem: "UIComponents",
    category: "RatingRequestPreview"
)

#Preview("Mock Reviews") {
    RatingRequestScreen(
        appId: "1658216708",
        appRatingProvider: MockAppRatingProvider.withMockReviews,
        primaryButtonAction: {
            kPreviewLogger.debug("Rating Requested")
        },
        secondaryButtonAction: {
            kPreviewLogger.debug("Maybe later tapped")
        }
    )
    .tint(.accentColor)
    #if os(macOS)
        .frame(width: 400, height: 600)
    #endif
}

#Preview("No Reviews") {
    RatingRequestScreen(
        appId: "1658216708",
        appRatingProvider: MockAppRatingProvider.noReviews,
        primaryButtonAction: {
            kPreviewLogger.debug("Rating Requested")
        },
        secondaryButtonAction: {
            kPreviewLogger.debug("Maybe later tapped")
        }
    )
    #if os(macOS)
    .frame(width: 400, height: 600)
    #endif
}

#Preview("No Ratings or Reviews") {
    RatingRequestScreen(
        appId: "1658216708",
        appRatingProvider: MockAppRatingProvider.noRatingsOrReviews,
        primaryButtonAction: {
            kPreviewLogger.debug("Rating Requested")
        },
        secondaryButtonAction: {
            kPreviewLogger.debug("Maybe later tapped")
        }
    )
    #if os(macOS)
    .frame(width: 400, height: 600)
    #endif
}

#Preview("Error State") {
    RatingRequestScreen(
        appId: "1658216708",
        appRatingProvider: MockAppRatingProvider.throwsError,
        primaryButtonAction: {
            kPreviewLogger.debug("Rating Requested")
        },
        secondaryButtonAction: {
            kPreviewLogger.debug("Maybe later tapped")
        },
        onError: { error in
            kPreviewLogger.error(
                "Error occurred: \(error.localizedDescription, privacy: .public)"
            )
        }
    )
    #if os(macOS)
    .frame(width: 400, height: 600)
    #endif
}
