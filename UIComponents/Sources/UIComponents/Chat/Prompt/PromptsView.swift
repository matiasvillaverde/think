import Abstractions
import Database
import SwiftData
import SwiftUI

internal struct PromptsView: View {
    @Environment(\.generator)
    private var viewModel: ViewModelGenerating

    @Environment(\.controller)
    private var controller: ViewInteractionController

    @State private var isAnimating: Bool = false

    @Bindable var chat: Chat

    @Query private var prompts: [Prompt]

    internal init(chat: Chat) {
        self.chat = chat

        let personalityId: UUID = chat.personality.id
        _prompts = Query(
            filter: #Predicate<Prompt> { prompt in
                prompt.personality?.id == personalityId
            },
            sort: \Prompt.title,
            animation: .easeInOut
        )
    }

    internal var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Constants.kItemSpacing) {
                if isModelLoading {
                    skeletonContent
                } else {
                    promptsContent
                }
            }
            .padding()
        }
        .onAppear {
            withAnimation {
                isAnimating = true
            }
        }
    }

    @ViewBuilder private var skeletonContent: some View {
        ForEach(0 ..< Constants.kSkeletonItemCount, id: \.self) { index in
            SkeletonPromptItem(index: index, isAnimating: isAnimating)
        }
    }

    @ViewBuilder private var promptsContent: some View {
        ForEach(prompts.indices, id: \.self) { index in
            PromptItemView(
                title: prompts[index].title,
                subtitle: prompts[index].subtitle,
                index: index,
                isAnimating: isAnimating
            ) {
                let prompt: String = prompts[index].prompt

                #if os(iOS)
                    controller.removeFocus?()
                #endif
                Task.detached(priority: .userInitiated) {
                    await viewModel.generate(
                        prompt: prompt,
                        overrideAction: nil
                    )
                }
            }
        }
    }

    // MARK: - Private Properties

    private var isModelLoading: Bool {
        if let lastMessage = chat.messages.last {
            return lastMessage.languageModel.runtimeState == .loading ||
                lastMessage.imageModel.runtimeState == .loading
        }
        return chat.languageModel.runtimeState == .loading
    }

    // Constants to eliminate magic numbers
    /// Layout constants for prompts view components
    internal enum Constants {
        // Animation constants
        static let animationItemDelayFactor: Double = 0.05
        static let animationInitialYOffset: CGFloat = 15
        static let animationShimmerDuration: Double = 1.5
        static let animationShimmerOffset: CGFloat = 2.0

        // Skeleton constants
        static let skeletonSpacing: CGFloat = 8
        static let skeletonTitleHeight: CGFloat = 20
        static let skeletonTitleMaxWidth: CGFloat = 180
        static let skeletonSubtitleHeight: CGFloat = 16
        static let skeletonSubtitleMaxWidth: CGFloat = 240
        static let skeletonCornerRadius: CGFloat = 4
        static let skeletonPrimaryOpacity: Double = 0.3
        static let skeletonSecondaryOpacity: Double = 0.1
        static let skeletonGradientStartOffset: CGFloat = -0.5
        static let skeletonGradientEndOffset: CGFloat = 0.5
        static let skeletonGradientY: CGFloat = 0.5
        static let skeletonCardWidth: CGFloat = 280
        static let kItemSpacing: CGFloat = 10
        static let kCornerRadius: CGFloat = 10
        static let kSkeletonItemCount: Int = 4
    }
}

// Simple skeleton loader without external dependencies
private struct SkeletonPromptItem: View {
    let index: Int
    let isAnimating: Bool
    @State private var shimmerOffset: CGFloat = -1.0

    var body: some View {
        VStack(alignment: .leading, spacing: PromptsView.Constants.skeletonSpacing) {
            // Title skeleton
            RoundedRectangle(cornerRadius: PromptsView.Constants.skeletonCornerRadius)
                .fill(shimmerGradient)
                .frame(
                    width: PromptsView.Constants.skeletonTitleMaxWidth,
                    height: PromptsView.Constants.skeletonTitleHeight
                )

            // Subtitle skeleton
            RoundedRectangle(cornerRadius: PromptsView.Constants.skeletonCornerRadius)
                .fill(shimmerGradient)
                .frame(
                    width: PromptsView.Constants.skeletonSubtitleMaxWidth,
                    height: PromptsView.Constants.skeletonSubtitleHeight
                )
        }
        .padding()
        .frame(width: PromptsView.Constants.skeletonCardWidth)
        .background(Color.backgroundPrimary)
        .cornerRadius(PromptsView.Constants.kCornerRadius)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : PromptsView.Constants.animationInitialYOffset)
        .animation(
            .easeInOut.delay(PromptsView.Constants.animationItemDelayFactor * Double(index)),
            value: isAnimating
        )
        .onAppear {
            withAnimation(
                .linear(duration: PromptsView.Constants.animationShimmerDuration)
                    .repeatForever(autoreverses: false)
            ) {
                shimmerOffset = PromptsView.Constants.animationShimmerOffset
            }
        }
    }

    private var shimmerGradient: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.paletteGray.opacity(PromptsView.Constants.skeletonPrimaryOpacity),
                Color.paletteGray.opacity(PromptsView.Constants.skeletonSecondaryOpacity),
                Color.paletteGray.opacity(PromptsView.Constants.skeletonPrimaryOpacity)
            ],
            startPoint: .init(
                x: shimmerOffset + PromptsView.Constants.skeletonGradientStartOffset,
                y: PromptsView.Constants.skeletonGradientY
            ),
            endPoint: .init(
                x: shimmerOffset + PromptsView.Constants.skeletonGradientEndOffset,
                y: PromptsView.Constants.skeletonGradientY
            )
        )
    }
}

#if DEBUG
    #Preview(traits: .modifier(PreviewDatabase())) {
        @Previewable @State var chat: Chat = Chat.preview
        PromptsView(chat: chat)
    }
#endif
