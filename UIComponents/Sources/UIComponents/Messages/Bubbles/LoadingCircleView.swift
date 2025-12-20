import SwiftUI

public struct LoadingCircleView: View {
    // Animation constants
    private enum Constants {
        static let initialScale: CGFloat = 0.5
        static let finalScale: CGFloat = 1.2
        static let animationDuration: Double = 0.8
        static let defaultOpacity: Double = 0.7
        static let pulseMinOpacity: Double = 0.1
        static let size: CGFloat = 15
        static let color: Color = .marketingPrimary
        static let defaultScale: CGFloat = 1.0
        static let hueDurationMultiplier: Double = 5.0
        static let shadowOpacity: Double = 0.5
        static let shadowRadius: CGFloat = 5.0
        static let shadowOffsetX: CGFloat = 0.0
        static let shadowOffsetY: CGFloat = 0.0
    }

    @State private var scale: CGFloat = Constants.initialScale

    public var body: some View {
        ZStack {
            // Main circle
            circle
        }
        .onAppear {
            // Scale animation
            withAnimation(Animation.easeInOut(duration: Constants.animationDuration)
                .repeatForever(autoreverses: true)) {
                scale = Constants.finalScale
            }
        }
    }

    private var circle: some View {
        Circle()
            .fill(Constants.color)
            .frame(width: Constants.size, height: Constants.size)
            .scaleEffect(scale)
            .shadow(
                color: Constants.color.opacity(Constants.shadowOpacity),
                radius: Constants.shadowRadius,
                x: Constants.shadowOffsetX,
                y: Constants.shadowOffsetY
            )
    }
}

#Preview {
    LoadingCircleView()
}
