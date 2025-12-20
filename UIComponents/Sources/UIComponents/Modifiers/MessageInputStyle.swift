import SwiftUI

#if os(macOS)

    // MARK: - Constants

    private enum InputStyleConstants {
        static let cornerRadius: CGFloat = 20
        static let horizontalPadding: CGFloat = 1
        static let outerHorizontalPadding: CGFloat = 10
        static let bottomPadding: CGFloat = 10
        static let strokeLineWidth: CGFloat = 0.1
        static let strokeOpacity: Double = 0.2
    }

    // MARK: - View Modifiers

    public struct MessageInputStyle: ViewModifier {
        public func body(content: Content) -> some View {
            content
                .padding()
                .padding(.horizontal, InputStyleConstants.horizontalPadding)
                .background(Color.backgroundPrimary)
                .cornerRadius(InputStyleConstants.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: InputStyleConstants.cornerRadius)
                        .stroke(Color.iconPrimary, lineWidth: InputStyleConstants.strokeLineWidth)
                        .opacity(InputStyleConstants.strokeOpacity)
                )
                .padding(.horizontal, InputStyleConstants.outerHorizontalPadding)
                .padding(.bottom, InputStyleConstants.bottomPadding)
        }
    }

#else

    // MARK: - Constants

    private enum InputStyleConstants {
        static let cornerRadius: CGFloat = 20
        static let horizontalPadding: CGFloat = 1
        static let strokeLineWidth: CGFloat = 0.1
        static let strokeOpacity: Double = 0.2
    }

    // MARK: - View Modifiers

    public struct MessageInputStyle: ViewModifier {
        public func body(content: Content) -> some View {
            content
                .padding()
                .padding(.horizontal, InputStyleConstants.horizontalPadding)
                .background(Color.backgroundPrimary)
                .clipShape(
                    RoundedCorner(
                        radius: InputStyleConstants.cornerRadius,
                        corners: [.topLeft, .topRight] // Only top corners
                    )
                )
                .overlay(
                    RoundedCorner(
                        radius: InputStyleConstants.cornerRadius,
                        corners: [.topLeft, .topRight]
                    )
                    .stroke(Color.iconPrimary, lineWidth: InputStyleConstants.strokeLineWidth)
                    .opacity(InputStyleConstants.strokeOpacity)
                )
        }
    }

    // Helper shape for custom corner radius
    public struct RoundedCorner: Shape {
        var radius: CGFloat
        var corners: UIRectCorner

        public func path(in rect: CGRect) -> Path {
            let path: UIBezierPath = UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: corners,
                cornerRadii: CGSize(width: radius, height: radius)
            )
            return Path(path.cgPath)
        }
    }

#endif

// MARK: - View Extensions

extension View {
    /// Applies consistent styling to message input components
    /// - Returns: A modified view with the message input style applied
    func messageInputStyle() -> some View {
        modifier(MessageInputStyle())
    }

    /// Applies shadow styling for input components
    /// - Returns: A view with shadow applied
    func applyShadow() -> some View {
        shadow(
            color: .black.opacity(MessageInputView.Constants.shadowOpacity),
            radius: MessageInputView.Constants.shadowRadius,
            x: MessageInputView.Constants.shadowOffsetX,
            y: MessageInputView.Constants.shadowOffsetY
        )
    }
}
