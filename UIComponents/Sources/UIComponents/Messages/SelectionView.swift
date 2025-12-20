import SwiftUI

public struct SelectionView: View {
    // MARK: - Constants

    private enum Constants {
        static let minWidth: CGFloat = 600
        static let minHeight: CGFloat = 400
    }

    // MARK: - Properties

    @State private var text: String
    @Binding var showingSelectionView: Bool

    public init(text: String?, showingSelectionView: Binding<Bool>) {
        _text = State(initialValue: text ?? "")
        _showingSelectionView = showingSelectionView
    }

    public var body: some View {
        platformSpecificView()
    }

    @ViewBuilder
    private func platformSpecificView() -> some View {
        #if os(iOS) || os(visionOS)
            NavigationView {
                contentView()
            }
        #else
            contentView()
        #endif
    }

    @ViewBuilder
    private func contentView() -> some View {
        TextEditor(text: $text)
            .font(.body)
            .background(Color.backgroundPrimary)
            .padding()
        #if os(iOS) || os(visionOS)
            .navigationBarTitle(
                String(
                    localized: "Select Text",
                    bundle: .module
                ),
                displayMode: .inline
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSelectionView = false
                    }, label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.iconPrimary)
                            .accessibilityLabel("Close window")
                    })
                }
            }
        #elseif os(macOS)
            .frame(minWidth: Constants.minWidth, minHeight: Constants.minHeight)
        #endif
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var text: String = "Hello, world!"
    @Previewable @State var showingSelectionView: Bool = true

    SelectionView(
        text: text,
        showingSelectionView: $showingSelectionView
    )
}
