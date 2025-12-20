import Highlightr
import MarkdownUI
import SwiftUI

public struct CodeBlockView: View {
    // MARK: - Constants

    private enum Constants {
        // Button
        static let copyButtonWidth: CGFloat = 80
        static let buttonPadding: CGFloat = 4
        static let buttonCornerRadius: CGFloat = 4
        static let buttonStrokeWidth: CGFloat = 1

        // Header
        static let headerVerticalPadding: CGFloat = 8

        // Container
        static let containerCornerRadius: CGFloat = 8
        static let containerStrokeWidth: CGFloat = 0.2

        // Content
        static let contentTopPadding: CGFloat = 8

        // Animation
        static let copiedResetDelay: Double = 2.0
    }

    let configuration: CodeBlockConfiguration
    @State private var isCopied: Bool = false

    public var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(configuration.language?.capitalized ?? "")
                    .foregroundStyle(.white)

                Spacer()

                Button(action: copyCodeAction) {
                    Text(isCopied ? "Copied!" : "Copy", bundle: .module)
                        .foregroundStyle(.white)
                        .frame(width: Constants.copyButtonWidth)
                        .padding(Constants.buttonPadding)
                }
                .buttonStyle(.plain)
                .cornerRadius(Constants.buttonCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.buttonCornerRadius)
                        .stroke(
                            Color.buttonStroke,
                            lineWidth: Constants.buttonStrokeWidth
                        )
                )
            }
            .padding(.horizontal)
            .padding(.vertical, Constants.headerVerticalPadding)
            .background(Color.headerBackground)

            configuration.label
                .padding(.top, Constants.contentTopPadding)
                .padding(.bottom)
                .padding(.horizontal)
                .monospaced()
        }
        .background(Color.containerBackground)
        .cornerRadius(Constants.containerCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Constants.containerCornerRadius)
                .stroke(.secondary, lineWidth: Constants.containerStrokeWidth)
        )
    }

    private func copyCodeAction() {
        #if os(iOS) || os(visionOS)
            let pasteboard: UIPasteboard = UIPasteboard.general
            pasteboard.string = configuration.content
        #elseif os(macOS)
            let pasteboard: NSPasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(configuration.content, forType: .string)
        #endif

        isCopied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.copiedResetDelay) {
            isCopied = false
        }
    }
}

extension CodeBlockConfiguration: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(language)
        hasher.combine(content)
    }

    public static func == (lhs: CodeBlockConfiguration, rhs: CodeBlockConfiguration) -> Bool {
        lhs.language == rhs.language &&
            lhs.content == rhs.content
    }
}

public struct CodeHighlighter: CodeSyntaxHighlighter {
    @MainActor static let theme: Self = .init()

    // MARK: - Constants

    private enum Constants {
        static let codeTextSize: CGFloat = 15
        static let defaultTheme: String = "atom-one-dark"
    }

    private let highlightr: Highlightr

    init() {
        guard let highlightrInstance = Highlightr() else {
            fatalError("Failed to initialize Highlightr")
        }

        highlightr = highlightrInstance
        highlightr.setTheme(to: Constants.defaultTheme)
    }

    public func highlightCode(_ code: String, language: String?) -> Text {
        let highlightedCode: NSAttributedString? = if let language, !language.isEmpty {
            highlightr.highlight(code, as: language)
        } else {
            highlightr.highlight(code)
        }

        guard let highlightedCode else {
            return Text(code)
        }

        var attributedCode: AttributedString = AttributedString(highlightedCode)
        attributedCode.font = .system(size: Constants.codeTextSize, design: .monospaced)

        return Text(attributedCode)
    }
}
