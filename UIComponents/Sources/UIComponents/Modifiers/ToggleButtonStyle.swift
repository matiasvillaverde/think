import SwiftUI

// MARK: - Constants

private enum ToggleConstants {
    static let horizontalPadding: CGFloat = 10
    static let verticalPadding: CGFloat = 4
    static let buttonHeight: CGFloat = 32
    static let cornerRadius: CGFloat = 16
    static let animationDuration: Double = 0.2
    static let trailingPadding: CGFloat = 10
    static let lineWidth: CGFloat = 1
    static let opacity: CGFloat = 0.2
}

// MARK: - Toggle Button Style

public struct ToggleButtonStyle: ViewModifier {
    let isActive: Bool

    public func body(content: Content) -> some View {
        content
            .font(.footnote)
            .bold()
            .padding(.horizontal, ToggleConstants.horizontalPadding)
            .padding(.vertical, ToggleConstants.verticalPadding)
            .frame(height: ToggleConstants.buttonHeight) // Fixed height for all buttons
            .background(isActive ? Color.marketingSecondary : Color.paletteClear)
            .overlay(
                RoundedRectangle(cornerRadius: ToggleConstants.cornerRadius)
                    .stroke(Color.textSecondary, lineWidth: ToggleConstants.lineWidth)
                    .opacity(ToggleConstants.opacity)
            )
            .clipShape(RoundedRectangle(cornerRadius: ToggleConstants.cornerRadius))
            .animation(.easeInOut(duration: ToggleConstants.animationDuration), value: isActive)
            .foregroundColor(isActive ? Color.marketingSecondaryText : Color.textPrimary)
            .padding(.trailing, ToggleConstants.trailingPadding)
    }
}

extension View {
    func toggleStyle(isActive: Bool) -> some View {
        modifier(ToggleButtonStyle(isActive: isActive))
    }
}

// MARK: - Generic Toggle Button

public struct ToggleButton: View {
    let title: String
    let activeIcon: String
    let inactiveIcon: String
    let isActive: Bool
    let action: () -> Void

    public var body: some View {
        Button(action: action) {
            Label(title, systemImage: isActive ? activeIcon : inactiveIcon)
        }
        .buttonStyle(.borderless)
        .toggleStyle(isActive: isActive)
    }
}
