// BaseTextField.swift
#if canImport(UIKit)
    import SwiftUI
#endif
#if canImport(AppKit)
    import SwiftUI
    import SwiftUIIntrospect
#endif

#if canImport(UIKit)
    internal struct BaseTextField: View {
        private enum Constants {
            static let lineLimit: Int = 5
        }

        private var titleKey: LocalizedStringKey

        @Binding private var text: String
        private var action: () -> Void

        init(_ titleKey: LocalizedStringKey, text: Binding<String>, action: @escaping () -> Void) {
            self.titleKey = titleKey
            _text = text
            self.action = action
        }

        var body: some View {
            TextField(titleKey, text: $text, axis: .vertical)
                .lineLimit(Constants.lineLimit)
                .onSubmit(action)
        }
    }
#endif

#if canImport(AppKit)
    internal struct BaseTextField: View {
        private var titleKey: LocalizedStringKey

        @Binding private var text: String
        private var action: () -> Void

        init(_ titleKey: LocalizedStringKey, text: Binding<String>, action: @escaping () -> Void) {
            self.titleKey = titleKey
            _text = text
            self.action = action
        }

        var body: some View {
            TextField(titleKey, text: $text, axis: .vertical)
                .introspect(.textField(axis: .vertical), on: .macOS(.v14)) { textField in
                    textField.lineBreakMode = .byWordWrapping
                }
                .onSubmit(macOS_action)
        }

        private func macOS_action() {
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                text.appendNewLine()
            } else {
                action()
            }
        }
    }
#endif
