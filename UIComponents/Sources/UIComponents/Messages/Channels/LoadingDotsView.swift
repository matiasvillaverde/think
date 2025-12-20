import Combine
import SwiftUI

// MARK: - Animation Views

private enum LoadingAnimationConstants {
    static let loadingDotsInterval: TimeInterval = 0.5
    static let maxDotCount: Int = 4
    static let pulsingDuration: Double = 1.5
    static let pulsingMinOpacity: Double = 0.5
    static let pulsingMinScale: Double = 0.95
}

internal struct LoadingDotsView: View {
    @State private var dotCount: Int = 0
    private let timer: Publishers.Autoconnect<Timer.TimerPublisher> = Timer
        .publish(
            every: LoadingAnimationConstants.loadingDotsInterval,
            on: .main,
            in: .common
        )
        .autoconnect()

    internal var body: some View {
        Text(String(repeating: "•", count: dotCount))
            .font(.caption)
            .foregroundColor(.textSecondary)
            .onReceive(timer) { _ in
                dotCount = (dotCount + 1) % LoadingAnimationConstants.maxDotCount
            }
    }
}

// MARK: - Animation Modifiers

internal struct PulsingAnimationModifier: ViewModifier {
    let isActive: Bool
    @State private var isPulsing: Bool = false

    func body(content: Content) -> some View {
        content
            .opacity(
                isActive
                    ? (isPulsing ? LoadingAnimationConstants.pulsingMinOpacity : 1.0)
                    : 1.0
            )
            .scaleEffect(
                isActive
                    ? (isPulsing ? LoadingAnimationConstants.pulsingMinScale : 1.0)
                    : 1.0
            )
            .animation(
                isActive
                    ? Animation
                        .easeInOut(duration: LoadingAnimationConstants.pulsingDuration)
                        .repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onAppear {
                if isActive {
                    isPulsing = true
                }
            }
            .onChange(of: isActive) { _, newValue in
                isPulsing = newValue
            }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Loading Dots Animation") {
        HStack(spacing: 20) {
            Text("Loading")
                .font(.caption)
            LoadingDotsView()
        }
        .padding()
    }

    #Preview("Pulsing Animation") {
        HStack(spacing: 40) {
            Image(systemName: "brain")
                .modifier(PulsingAnimationModifier(isActive: true))
            Image(systemName: "brain")
                .modifier(PulsingAnimationModifier(isActive: false))
        }
        .font(.largeTitle)
        .padding()
    }
#endif
