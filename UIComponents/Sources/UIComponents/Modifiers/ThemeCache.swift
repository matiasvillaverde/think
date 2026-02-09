import Foundation
import MarkdownUI
import OSLog
import SwiftUI

// Extract magic numbers into constants
private enum Constants {
    static let bodyFontSize: Double = 17.0
    static let codeFontSize: Double = 15.0
    static let paragraphLineSpacing: Double = 0.25
}

/// Cache for markdown themes and code block views to improve performance
@preconcurrency
@MainActor
public final class ThemeCache {
    nonisolated private static let logger: Logger = Logger(
        subsystem: "UIComponents",
        category: "ThemeCache"
    )

    deinit {
        #if DEBUG
            Self.logger.debug("deinit ThemeCache")
        #endif
    }

    /// Shared singleton instance of the theme cache
    public static let shared: ThemeCache = .init()
    private var cachedTheme: Theme?
    private var cachedCodeBlocks: [CodeBlockConfiguration: CodeBlockView] = [:]

    /// Returns a cached theme or creates a new one
    /// - Returns: A configured MarkdownUI theme
    public func getTheme() -> Theme {
        if let existingTheme = cachedTheme {
            return existingTheme
        }

        let newTheme: Theme = Theme()
            .text {
                FontSize(Constants.bodyFontSize)
            }
            .paragraph { configuration in
                configuration.label
                    .relativeLineSpacing(.em(Constants.paragraphLineSpacing))
            }
            .code {
                FontSize(Constants.codeFontSize)
                FontFamilyVariant(.monospaced)
            }
            .codeBlock { [weak self] configuration in
                self?.getCodeBlockView(for: configuration)
                    ?? CodeBlockView(configuration: configuration)
            }

        cachedTheme = newTheme
        return newTheme
    }

    private func getCodeBlockView(for configuration: CodeBlockConfiguration) -> CodeBlockView {
        if let cachedView = cachedCodeBlocks[configuration] {
            return cachedView
        }

        let newView: CodeBlockView = CodeBlockView(configuration: configuration)
        cachedCodeBlocks[configuration] = newView
        return newView
    }
}
