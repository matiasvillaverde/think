import SwiftUI

private enum ChartGestureConstants {
    static let minScale: CGFloat = 1.0
    static let maxScale: CGFloat = 3.0
    static let doubleTapScale: CGFloat = 2.0
    static let doubleTapCount: Int = 2
    static let centerDivisor: CGFloat = 2
    static let longPressDuration: Double = 0.5
    static let hoverOpacity: Double = 0.3
    static let crosshairOpacity: Double = 0.5
    static let hoverCircleSize: CGFloat = 20
    static let crosshairLineWidth: CGFloat = 1
    static let swipeThreshold: CGFloat = 50
    static let zeroIndex: Int = 0
}

/// Gesture handlers for chart interactions
public struct ChartGestureModifier: ViewModifier {
    @Binding var selectedDataPoint: Int?
    @Binding var isZoomed: Bool
    @State private var dragOffset: CGSize = .zero
    @State private var scale: CGFloat = 1.0

    let onTap: ((CGPoint) -> Void)?
    let onLongPress: ((CGPoint) -> Void)?
    let onDrag: ((CGSize) -> Void)?

    public init(
        selectedDataPoint: Binding<Int?>,
        isZoomed: Binding<Bool>,
        onTap: ((CGPoint) -> Void)? = nil,
        onLongPress: ((CGPoint) -> Void)? = nil,
        onDrag: ((CGSize) -> Void)? = nil
    ) {
        _selectedDataPoint = selectedDataPoint
        _isZoomed = isZoomed
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.onDrag = onDrag
    }

    public func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .scaleEffect(scale)
                .offset(dragOffset)
                .gesture(tapGesture(in: geometry))
                .gesture(longPressGesture(in: geometry))
                .gesture(dragGesture)
                .gesture(magnificationGesture)
                .onTapGesture(count: ChartGestureConstants.doubleTapCount) {
                    withAnimation(.spring()) {
                        if scale > ChartGestureConstants.minScale {
                            scale = ChartGestureConstants.minScale
                            dragOffset = .zero
                            isZoomed = false
                        } else {
                            scale = ChartGestureConstants.doubleTapScale
                            isZoomed = true
                        }
                    }
                }
        }
    }

    private func tapGesture(in geometry: GeometryProxy) -> some Gesture {
        TapGesture()
            .onEnded { _ in
                let location: CGPoint = CGPoint(
                    x: geometry.size.width / ChartGestureConstants.centerDivisor,
                    y: geometry.size.height / ChartGestureConstants.centerDivisor
                )
                onTap?(location)
            }
    }

    private func longPressGesture(in geometry: GeometryProxy) -> some Gesture {
        LongPressGesture(minimumDuration: ChartGestureConstants.longPressDuration)
            .onEnded { _ in
                let location: CGPoint = CGPoint(
                    x: geometry.size.width / ChartGestureConstants.centerDivisor,
                    y: geometry.size.height / ChartGestureConstants.centerDivisor
                )
                onLongPress?(location)
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if isZoomed {
                    dragOffset = value.translation
                }
            }
            .onEnded { value in
                onDrag?(value.translation)
                withAnimation(.spring()) {
                    dragOffset = .zero
                }
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale: CGFloat = scale * value
                scale = min(
                    max(newScale, ChartGestureConstants.minScale),
                    ChartGestureConstants.maxScale
                )
                isZoomed = scale > ChartGestureConstants.minScale
            }
    }
}

/// Chart hover effect modifier
public struct ChartHoverModifier: ViewModifier {
    @State private var isHovering: Bool = false
    @State private var hoverLocation: CGPoint = .zero

    let onHover: ((Bool, CGPoint) -> Void)?

    public init(onHover: ((Bool, CGPoint) -> Void)? = nil) {
        self.onHover = onHover
    }

    public func body(content: Content) -> some View {
        content
        #if os(macOS)
        .onHover { hovering in
            isHovering = hovering
            onHover?(hovering, hoverLocation)
        }
        .onContinuousHover { phase in
            switch phase {
            case let .active(location):
                hoverLocation = location
                onHover?(true, location)

            case .ended:
                onHover?(false, .zero)
            }
        }
        #endif
        .overlay(
            isHovering
                ? HoverOverlay(location: hoverLocation)
                : nil
        )
    }
}

/// Hover overlay for charts
private struct HoverOverlay: View {
    let location: CGPoint

    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(Color.accentColor.opacity(ChartGestureConstants.hoverOpacity))
                .frame(
                    width: ChartGestureConstants.hoverCircleSize,
                    height: ChartGestureConstants.hoverCircleSize
                )
                .position(location)

            Path { path in
                path.move(to: CGPoint(x: location.x, y: 0))
                path.addLine(to: CGPoint(x: location.x, y: geometry.size.height))
            }
            .stroke(
                Color.accentColor.opacity(ChartGestureConstants.crosshairOpacity),
                lineWidth: ChartGestureConstants.crosshairLineWidth
            )

            Path { path in
                path.move(to: CGPoint(x: 0, y: location.y))
                path.addLine(to: CGPoint(x: geometry.size.width, y: location.y))
            }
            .stroke(
                Color.accentColor.opacity(ChartGestureConstants.crosshairOpacity),
                lineWidth: ChartGestureConstants.crosshairLineWidth
            )
        }
        .allowsHitTesting(false)
    }
}

/// Swipe gesture for chart navigation
public struct ChartSwipeModifier: ViewModifier {
    @Binding var currentIndex: Int
    let maxIndex: Int
    let onSwipe: ((SwipeDirection) -> Void)?

    public enum SwipeDirection {
        case left, right, upward, down
    }

    public init(
        currentIndex: Binding<Int>,
        maxIndex: Int,
        onSwipe: ((SwipeDirection) -> Void)? = nil
    ) {
        _currentIndex = currentIndex
        self.maxIndex = maxIndex
        self.onSwipe = onSwipe
    }

    public func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let horizontalAmount: CGFloat = value.translation.width
                        let verticalAmount: CGFloat = value.translation.height

                        if abs(horizontalAmount) > abs(verticalAmount) {
                            if horizontalAmount < -ChartGestureConstants.swipeThreshold {
                                // Swipe left
                                withAnimation {
                                    currentIndex = min(currentIndex + 1, maxIndex)
                                }
                                onSwipe?(.left)
                            } else if horizontalAmount > ChartGestureConstants.swipeThreshold {
                                // Swipe right
                                withAnimation {
                                    currentIndex = max(
                                        currentIndex - 1,
                                        ChartGestureConstants.zeroIndex
                                    )
                                }
                                onSwipe?(.right)
                            }
                        } else {
                            if verticalAmount < -ChartGestureConstants.swipeThreshold {
                                onSwipe?(.upward)
                            } else if verticalAmount > ChartGestureConstants.swipeThreshold {
                                onSwipe?(.down)
                            }
                        }
                    }
            )
    }
}

/// Extensions for easy gesture application
extension View {
    /// Applies chart gesture modifiers for interactive chart functionality
    /// - Parameters:
    ///   - selectedDataPoint: Binding to track selected data point
    ///   - isZoomed: Binding to track zoom state
    ///   - onTap: Optional tap gesture handler
    ///   - onLongPress: Optional long press gesture handler
    ///   - onDrag: Optional drag gesture handler
    /// - Returns: View with chart gesture modifiers
    func chartGestures(
        selectedDataPoint: Binding<Int?>,
        isZoomed: Binding<Bool>,
        onTap: ((CGPoint) -> Void)? = nil,
        onLongPress: ((CGPoint) -> Void)? = nil,
        onDrag: ((CGSize) -> Void)? = nil
    ) -> some View {
        modifier(
            ChartGestureModifier(
                selectedDataPoint: selectedDataPoint,
                isZoomed: isZoomed,
                onTap: onTap,
                onLongPress: onLongPress,
                onDrag: onDrag
            )
        )
    }

    /// Applies hover effects for chart interactions
    /// - Parameter onHover: Optional hover event handler
    /// - Returns: View with hover functionality
    func chartHover(
        onHover: ((Bool, CGPoint) -> Void)? = nil
    ) -> some View {
        modifier(ChartHoverModifier(onHover: onHover))
    }

    /// Applies swipe gesture recognition for chart navigation
    /// - Parameters:
    ///   - currentIndex: Binding to current index
    ///   - maxIndex: Maximum allowed index
    ///   - onSwipe: Optional swipe direction handler
    /// - Returns: View with swipe gesture functionality
    func chartSwipe(
        currentIndex: Binding<Int>,
        maxIndex: Int,
        onSwipe: ((ChartSwipeModifier.SwipeDirection) -> Void)? = nil
    ) -> some View {
        modifier(
            ChartSwipeModifier(
                currentIndex: currentIndex,
                maxIndex: maxIndex,
                onSwipe: onSwipe
            )
        )
    }
}
