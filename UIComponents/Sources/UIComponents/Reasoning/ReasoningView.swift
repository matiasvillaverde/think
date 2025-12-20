import Combine
import Database
import SwiftUI

internal struct ReasoningView: View {
    // **MARK: - Constants**
    private enum Constants {
        static let textSuffixLength: Int = 150
        static let fontSize: CGFloat = 11
        static let padding: CGFloat = 10
        static let animationDuration: Double = 0.3
        static let seconds: Int = 60
        static let gradientStartFraction: CGFloat = 0.0
        static let gradientEndFraction: CGFloat = 0.5
    }

    // MARK: - Properties

    @Bindable var message: Message
    @State private var showingFullView: Bool = false
    @State private var elapsedSeconds: Int = 0
    @State private var animatedThinking: String = ""
    @State private var isAnimating: Bool = false

    // Timer to update the elapsed time
    let timer: Publishers.Autoconnect<Timer.TimerPublisher> = Timer.publish(
        every: 1,
        on: .main,
        in: .common
    )
    .autoconnect()

    var formattedThinkingTime: String {
        if elapsedSeconds < Constants.seconds {
            return String(
                localized: "\(elapsedSeconds) second\(elapsedSeconds == 1 ? "" : "s")",
                bundle: .module,
                comment: "Elapsed thinking time in seconds"
            )
        }

        let minutes: Int = elapsedSeconds / Constants.seconds
        let seconds: Int = elapsedSeconds % Constants.seconds
        let minuteText: String = minutes == 1 ? "minute" : "minutes"
        let secondText: String = seconds == 1 ? "second" : "seconds"
        return String(
            localized: "\(minutes) \(minuteText) \(seconds) \(secondText)",
            bundle: .module,
            comment: "Elapsed thinking time in minutes and seconds"
        )
    }

    // MARK: - Body

    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    animatedSparklesIcon
                    Text(
                        String(
                            localized: "Thinking for \(formattedThinkingTime)",
                            bundle: .module,
                            comment: "AI thinking duration label"
                        )
                    )
                    .font(.body)
                    .bold()
                    .foregroundStyle(Color.marketingPrimary)
                    .foregroundColor(Color.backgroundSecondary)
                    .padding(.bottom)
                }

                Text(animatedThinking)
                    .font(.system(
                        size: Constants.fontSize,
                        weight: .medium,
                        design: .monospaced
                    ))
                    .foregroundColor(Color.textSecondary)
            }
            .padding(Constants.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PlainButtonStyle())
        .help(
            String(
                localized: "Reasoning process to find a better answer",
                bundle: .module,
                comment: "Tooltip for the 'Reasoning' button"
            )
        )
        .onReceive(timer) { _ in
            elapsedSeconds += 1
        }
        .onAppear {
            elapsedSeconds = 0
            animatedThinking = message.thinking ?? ""
            isAnimating = true
        }
        .onChange(of: message.thinking) { _, newValue in
            withAnimation(.easeInOut(duration: Constants.animationDuration)) {
                animatedThinking = newValue ?? ""
            }
        }
    }

    // MARK: - Actions

    private func toggle() {
        showingFullView.toggle()
    }

    private var animatedSparklesIcon: some View {
        Image(systemName: "brain.head.profile")
            .font(.title2)
            .foregroundStyle(
                EllipticalGradient(
                    colors: [Color.marketingPrimary, Color.marketingPrimary],
                    center: .center,
                    startRadiusFraction: Constants.gradientStartFraction,
                    endRadiusFraction: Constants.gradientEndFraction
                )
            )
            .symbolEffect(
                .pulse.byLayer,
                options: .speed(1).repeating,
                value: isAnimating
            )
            .symbolEffect(
                .bounce.down.byLayer,
                options: .speed(1).repeating,
                value: isAnimating
            )
            .accessibilityHidden(true)
    }
}

// **MARK: - Preview**
#if DEBUG
    #Preview {
        @Previewable @State var message: Message = .previewWithThinking

        ReasoningView(message: message)

        // Note: thinking is now computed from channels, can't be directly modified
        // Button(
        //     String(
        //         localized: "Update Text",
        //         bundle: .module,
        //         comment: "Button to update thinking text in preview"
        //     )
        // ) {
        //     message.thinking = String(
        //         localized: "\(message.thinking ?? "") Adding more text dynamically.",
        //         bundle: .module,
        //         comment: "Sample dynamic text for preview"
        //     )
        // }
        .padding()
    }
#endif
