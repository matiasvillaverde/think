import SwiftUI

// MARK: - Common Button Modifier

public struct CircleIconButtonModifier: ViewModifier {
    let systemName: String
    let color: Color

    public func body(content: Content) -> some View {
        content
            .buttonStyle(.borderless)
            .bold()
    }
}

// MARK: - View Extension

extension View {
    /// Applies a circle icon button style modifier
    /// - Parameters:
    ///   - systemName: SF Symbol name for the icon
    ///   - color: Color for the icon
    /// - Returns: View with circle icon button styling
    func circleIconButton(systemName: String, color: Color) -> some View {
        modifier(CircleIconButtonModifier(systemName: systemName, color: color))
    }
}

// MARK: - Common Circle Icon Button

internal struct CircleIconButton: View {
    let systemName: String
    let color: Color
    let action: () -> Void
    let keyboardShortcut: KeyboardShortcut?

    private enum Constants {
        static let iconSize: CGFloat = 20
        static let opacity: Double = 0.8
        static let animationResponse: Double = 0.3
        static let animationDamping: Double = 0.7
    }

    init(
        systemName: String,
        color: Color,
        keyboardShortcut: KeyboardShortcut? = nil,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.color = color
        self.keyboardShortcut = keyboardShortcut
        self.action = action
    }

    var body: some View {
        Button {
            withAnimation(
                .spring(
                    response: Constants.animationResponse,
                    dampingFraction: Constants.animationDamping
                )
            ) {
                action()
            }
        } label: {
            Image(systemName: systemName)
                .resizable()
                .frame(width: Constants.iconSize, height: Constants.iconSize)
                .foregroundColor(color)
                .opacity(Constants.opacity)
                .accessibilityLabel(systemName)
        }
        .bold()
        .buttonStyle(.borderless)
        .if(keyboardShortcut != nil) { view in
            view.keyboardShortcut(keyboardShortcut)
        }
    }
}

// MARK: - Conditional Modifier Extension

extension View {
    /// Conditionally applies a view transformation
    /// - Parameters:
    ///   - condition: Boolean condition to evaluate
    ///   - transform: Transformation to apply if condition is true
    /// - Returns: Transformed view if condition is true, otherwise original view
    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
