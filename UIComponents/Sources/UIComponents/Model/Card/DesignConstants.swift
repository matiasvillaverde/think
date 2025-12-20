import SwiftUI

/// Design constants to avoid magic numbers
internal enum DesignConstants {
    enum Spacing {
        static let xSmall: CGFloat = 2
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let standard: CGFloat = 12
        static let large: CGFloat = 16
        static let largeX: CGFloat = 20
        static let huge: CGFloat = 32
        static let lineCount: Int = 3
    }

    enum Size {
        static let iconSmall: CGFloat = 24
        static let iconMedium: CGFloat = 32
        static let downloadSectionWidth: CGFloat = 60
        static let emptyStateIcon: CGFloat = 60
        static let compactProgressHeight: CGFloat = 6
    }

    enum Radius {
        static let small: CGFloat = 8
        static let standard: CGFloat = 12
        static let rotation: CGFloat = -90
    }

    enum Opacity {
        static let trackBackground: CGFloat = 0.2
        static let shadow: CGFloat = 0.1
        static let line: CGFloat = 0.8
        static let backgroundBlur: CGFloat = 0.98
        static let strong: CGFloat = 0.7
        static let backgroundSubtle: CGFloat = 0.5
    }

    enum Line {
        static let thin: CGFloat = 1
        static let progressBar: CGFloat = 4
    }

    enum Font {
        static let scaleFactor: CGFloat = 0.8
        static let lineLimit: Int = 2
    }

    enum Shadow {
        static let radius: CGFloat = 2
        static let xAxis: CGFloat = 0
        static let yAxis: CGFloat = 1
        static let glassMorphismRadius: CGFloat = 10
        static let glassMorphismY: CGFloat = 2
        static let glassMorphismOpacity: CGFloat = 0.05
    }

    enum Percentage {
        static let hundred: Double = 100
    }

    enum Scale {
        static let small: CGFloat = 0.9
        static let pressed: CGFloat = 0.98
        static let hover: CGFloat = 1.02
        static let normal: CGFloat = 1.0
        static let transition: CGFloat = 0.95
    }

    enum Animation {
        static let spring: Double = 0.3
        static let springDamping: Double = 0.7
        static let press: Double = 0.2
        static let pressDamping: Double = 0.8
        static let quick: Double = 0.1
        static let standard: Double = 0.2
    }

    enum Modal {
        static let minWidth: CGFloat = 600
        static let minHeight: CGFloat = 500
        static let idealWidth: CGFloat = 1_200
        static let idealHeight: CGFloat = 800
    }
}
