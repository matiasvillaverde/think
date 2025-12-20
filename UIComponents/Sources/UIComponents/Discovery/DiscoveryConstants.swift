import Foundation

/// Constants for the Discovery UI components
internal enum DiscoveryConstants {
    enum Card {
        static let width: CGFloat = 280
        static let height: CGFloat = 320
        static let lineLimit: Int = 2
        static let squareImageSize: CGFloat = 140
        static let imageSize: CGSize = .init(width: squareImageSize, height: squareImageSize)
        static let logoIconSize: CGFloat = 60
        static let shadowRadius: CGFloat = 8
        static let shadowY: CGFloat = 4
        static let shadowOpacity: Double = 0.08
    }

    enum Numbers {
        static let million: Double = 1_000_000
        static let thousand: Double = 1_000
        static let progressScaleFactor: CGFloat = 1.5
        static let descriptionThreshold: Int = 200
        static let descriptionLineLimit: Int = 5
    }

    enum PreviewData {
        static let previewDownloads1: Int = 15_234
        static let previewLikes1: Int = 256
        static let previewDownloads2: Int = 12_456
        static let previewLikes2: Int = 342
        static let previewDownloads3: Int = 5_200
        static let previewLikes3: Int = 120
        static let previewDownloads4: Int = 12_000
        static let previewLikes4: Int = 340
        static let previewDownloads5: Int = 8_500
        static let previewLikes5: Int = 180
        static let previewDownloads6: Int = 25_000
        static let previewLikes6: Int = 580
        static let previewDownloads7: Int = 15_000
        static let previewLikes7: Int = 250
        static let previewDownloads8: Int = 15_000
        static let previewLikes8: Int = 250
        static let previewFileSize1: Int64 = 2_147_483_648
        static let previewFileSize2: Int64 = 1_024
        static let previewFileSize3: Int64 = 2_048
        static let loadingDelayNanoseconds: UInt64 = 1_000_000_000
        static let tagColumnMinWidth: CGFloat = 80
    }

    enum FilterBar {
        static let dividerHeight: CGFloat = 40
        static let dividerOpacity: Double = 0.3
        static let borderOpacity: Double = 0.2
    }

    enum Opacity {
        static let placeholder: Double = 0.5
        static let errorView: Double = 0.6
        static let logoText: Double = 0.6
        static let patternOverlay: Double = 0.03
        static let gradientSecondary: Double = 0.3
        static let extraLight: Double = 0.05
        static let light: Double = 0.1
        static let medium: Double = 0.3
        static let strong: Double = 0.8
        static let extraStrong: Double = 0.95
    }

    enum FontSize {
        static let cardTitle: CGFloat = 16
        static let cardAuthor: CGFloat = 13
        static let cardBadge: CGFloat = 11
        static let icon: CGFloat = 40
        static let logoMultiplier: CGFloat = 0.8
    }

    enum Multiplier {
        static let double: CGFloat = 2
    }
}
