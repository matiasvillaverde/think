import SwiftUI

internal struct CircularProgressView: View {
    let progress: Double
    let shouldAnimate: Bool
    @State private var isAnimating: Bool = false

    enum Constants {
        static let trackOpacity: Double = 0.3
        static let lineWidth: CGFloat = 4
        static let startAngle: Double = -90
        static let minProgress: Double = 0
        static let maxProgress: Double = 1.0
        static let previewProgress: Double = 0.7
        static let indicatorSize: CGFloat = 10
        static let scaleBig: CGFloat = 1
        static let scaleSmall: CGFloat = 0.5
        static let animationDuration: Double = 0.8
    }

    var body: some View {
        ZStack {
            // Circular track
            Circle()
                .stroke(Color.paletteGray.opacity(Constants.trackOpacity), lineWidth: Constants.lineWidth)

            // Progress arc
            processCircle
        }
        .onAppear {
            guard shouldAnimate else {
                return
            }
            isAnimating = true
        }
    }

    private var processCircle: some View {
        Circle()
            .trim(
                from: Constants.minProgress,
                to: CGFloat(
                    min(
                        progress,
                        Constants.maxProgress
                    )
                )
            )
            .stroke(
                Color.accentColor,
                style: StrokeStyle(
                    lineWidth: Constants.lineWidth,
                    lineCap: .round
                )
            )
            .rotationEffect(.degrees(Constants.startAngle))
    }
}

// Preview
#Preview {
    CircularProgressView(
        progress: CircularProgressView.Constants.previewProgress,
        shouldAnimate: true
    )
}
