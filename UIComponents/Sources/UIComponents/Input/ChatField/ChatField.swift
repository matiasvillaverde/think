import SwiftUI
import SwiftUIIntrospect

/// A SwiftUI view that provides a multiline, editable chat interface.
///
/// - Parameters:
///   - titleKey: A localized string key for the placeholder text.
///   - text: A binding to the text entered by the user.
///   - action: A closure to be executed when the user submits the text.
///   - leadingAccessory: A view builder for content to be displayed before the text field.
///   - trailingAccessory: A view builder for content to be displayed after the text field.
///   - footer: A view builder for content to be displayed below the text field.
internal struct ChatField<LeadingAccessory: View, TrailingAccessory: View, FooterView: View>: View {
    private var titleKey: LocalizedStringKey
    @Binding private var text: String

    private var action: () -> Void
    private var leadingAccessory: () -> LeadingAccessory
    private var trailingAccessory: () -> TrailingAccessory
    private var footer: () -> FooterView

    private var isTextFieldDisabled: Bool = false

    private struct Constants {
        let spacing: CGFloat = 8
    }

    /// Creates a new ChatField instance.
    ///
    /// - Parameters:
    ///   - titleKey: A localized string key for the placeholder text.
    ///   - text: A binding to the text entered by the user.
    ///   - action: A closure to be executed when the user submits the text.
    ///   - leadingAccessory: A view builder for content to be displayed before the text field.
    ///   - trailingAccessory: A view builder for content to be displayed after the text field.
    ///   - footer: A view builder for content to be displayed below the text field.
    init(
        _ titleKey: LocalizedStringKey,
        text: Binding<String>,
        action: @escaping () -> Void,
        @ViewBuilder leadingAccessory: @escaping () -> LeadingAccessory = { EmptyView() },
        @ViewBuilder trailingAccessory: @escaping () -> TrailingAccessory = { EmptyView() },
        @ViewBuilder footer: @escaping () -> FooterView = { EmptyView() }
    ) {
        self.titleKey = titleKey
        _text = text
        self.action = action
        self.leadingAccessory = leadingAccessory
        self.trailingAccessory = trailingAccessory
        self.footer = footer
    }

    var body: some View {
        VStack(spacing: Constants().spacing) {
            HStack(alignment: .bottom, spacing: Constants().spacing) {
                leadingAccessory()

                BaseTextField(titleKey, text: $text, action: action)
                    .disabled(isTextFieldDisabled)

                trailingAccessory()
            }

            footer()
        }
    }

    func chatFieldDisabled(_ disabled: Bool) -> Self {
        var view: Self = self
        view.isTextFieldDisabled = disabled
        return view
    }
}
