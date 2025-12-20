import SwiftUI

extension View {
    /// Applies a toast view modifier to display toast notifications
    /// - Parameter toast: Binding to the toast model to display
    /// - Returns: View with toast functionality
    func toastView(toast: Binding<Toast?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

/// A view modifier that displays toast notifications with auto-dismiss functionality
/// A view modifier that displays toast notifications with auto-dismiss functionality
public struct ToastViewModifier: ViewModifier {
    // MARK: - Constants

    private enum Constants {
        static let cornerRadius: CGFloat = 10
        static let bottomPadding: CGFloat = 40
        static let dismissDelay: Double = 2
    }

    /// Binding to the toast model that controls visibility and content
    @Binding var toast: Toast?

    /// Creates the view with toast overlay functionality
    /// - Parameter content: The content view to apply the toast to
    /// - Returns: View with toast overlay
    public func body(content: Content) -> some View {
        ZStack {
            content

            if let toast {
                VStack {
                    Spacer()

                    Text(toast.message)
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                                .fill(toast.style == .success ? Color.green : Color.red)
                        )
                        .padding(.bottom, Constants.bottomPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Constants.dismissDelay) {
                        withAnimation {
                            self.toast = nil
                        }
                    }
                }
            }
        }
        .animation(.easeInOut, value: toast)
    }
}

/// A more advanced toast modifier with haptic feedback and configurable duration
/// A more advanced toast modifier with haptic feedback and configurable duration
public struct ToastModifier: ViewModifier {
    // MARK: - Constants

    private enum Constants {
        static let verticalOffset: CGFloat = 32
        static let animation: Animation = .spring()
    }

    /// Binding to the toast model that controls visibility and content
    @Binding var toast: Toast?
    /// Work item for managing toast auto-dismiss timing
    @State private var workItem: DispatchWorkItem?

    /// Creates the view with advanced toast overlay functionality
    /// - Parameter content: The content view to apply the toast to
    /// - Returns: View with advanced toast overlay
    public func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                ZStack {
                    mainToastView()
                        .offset(y: Constants.verticalOffset)
                }.animation(Constants.animation, value: toast)
            )
            .onChange(of: toast) {
                showToast()
            }
    }

    @ViewBuilder
    func mainToastView() -> some View {
        if let toast {
            VStack {
                ToastView(
                    style: toast.style,
                    message: toast.message,
                    width: toast.width
                ) {
                    dismissToast()
                }
                Spacer()
            }
        }
    }

    private func showToast() {
        guard let toast else {
            return
        }

        #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        if toast.duration > 0 {
            workItem?.cancel()

            let task: DispatchWorkItem = DispatchWorkItem {
                dismissToast()
            }

            workItem = task
            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration, execute: task)
        }
    }

    private func dismissToast() {
        withAnimation {
            toast = nil
        }
        workItem?.cancel()
        workItem = nil
    }
}

/// Defines the visual style and behavior of toast notifications
public enum ToastStyle {
    /// Error style toast with red color
    case error
    /// Informational style toast with blue color
    case info
    /// Success style toast with green color
    case success
    /// Warning style toast with orange color
    case warning

    /// The theme color associated with this toast style
    public var themeColor: Color {
        switch self {
        case .error:
            Color.iconAlert

        case .warning:
            Color.iconWarning

        case .info:
            Color.iconInfo

        case .success:
            Color.iconConfirmation
        }
    }

    /// The SF Symbol icon name for this toast style
    public var iconFileName: String {
        switch self {
        case .info:
            "info.circle.fill"

        case .warning:
            "exclamationmark.triangle.fill"

        case .success:
            "checkmark.circle.fill"

        case .error:
            "xmark.circle.fill"
        }
    }
}
