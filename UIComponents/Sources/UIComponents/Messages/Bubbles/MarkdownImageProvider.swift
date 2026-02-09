import Foundation
import LaTeXSwiftUI
import MarkdownUI
import NetworkImage
import SwiftUI
#if canImport(AppKit)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

public struct MarkdownImageProvider: ImageProvider {
    let scaleFactor: CGFloat

    public func makeImage(url: URL?) -> some View {
        if let url {
            if url.isWebURL {
                // If network image
                networkImage(url: url)
            } else if url.isFileURL {
                // If file image
                fileImage(url: url)
            } else if url.absoluteString.hasPrefix("latex://"),
                let latexStr = url.withoutSchema.removingPercentEncoding {
                // If url is LaTeX
                LaTeXWrapper(latexString: latexStr)
            } else {
                // Try converting to absolute path
                let fileUrl: URL = URL(
                    fileURLWithPath: url.posixPath
                )
                // If file image
                fileImage(url: fileUrl)
            }
        } else {
            imageLoadError
        }
    }

    private func networkImage(
        url: URL?
    ) -> some View {
        AsyncImage(
            url: url
        ) { phase in
            switch phase {
            case .empty:
                // Show loading indicator when image is loading
                ProgressView()
                    .foregroundColor(Color.iconPrimary)
                    .padding()

            case .failure:
                // Show error view when loading fails
                imageLoadError

            case let .success(image):
                // Display image in its original size (without resizable and aspectRatio)
                image
                    .renderingMode(.original)
                    .draggable(image)
                    .padding(.leading, 1)

            @unknown default:
                imageLoadError
            }
        }
    }

    private func fileImage(url: URL?) -> some View {
        Group {
            if let url {
                #if os(macOS)
                    if let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .draggable(nsImage)
                            .padding(.leading, 1)
                    } else {
                        imageLoadError
                    }
                #elseif os(iOS)
                    if let data = try? Data(contentsOf: url),
                        let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .onDrag {
                                NSItemProvider(object: uiImage)
                            }
                            .padding(.leading, 1)
                    } else {
                        imageLoadError
                    }
                #endif
            } else {
                imageLoadError
            }
        }
    }

    var imageLoadError: some View {
        Label(
            "Error loading image",
            systemImage: "exclamationmark.square.fill"
        )
        .foregroundColor(Color.iconAlert)
    }
}

public struct MarkdownInlineImageProvider: InlineImageProvider {
    let scaleFactor: CGFloat

    private enum Constants {
        static let scaleFactor: CGFloat = 2
        static let padding: CGFloat = 3
        static let offset: CGFloat = 2.75
    }

    @preconcurrency
    @MainActor
    public func image(
        with url: URL,
        label: String
    ) async throws -> Image {
        if url.isWebURL {
            let scale: CGFloat = Constants.scaleFactor / scaleFactor
            let image: Image = try await Image(
                DefaultNetworkImageLoader.shared.image(from: url),
                scale: scale,
                label: Text(label)
            )
            return image.renderingMode(.template).resizable()
        }

        if url.absoluteString.hasPrefix("latex://"),
            let latexStr = url.withoutSchema.removingPercentEncoding,
            let latexImage: Image = LaTeX(latexStr)
                .blockMode(.alwaysInline)
                .errorMode(.original)
                .padding(.horizontal, Constants.padding)
                .offset(y: Constants.offset)
                .generateImage(
                    scale: scaleFactor
                ) {
            return latexImage
                .renderingMode(.template)
                .resizable()
        }
        return Image(systemName: "questionmark.square.fill")
    }
}

extension URL {
    /// A `Bool` representing iif the URL is a web URL
    var isWebURL: Bool {
        absoluteString.hasPrefix("http://") ||
            absoluteString.hasPrefix("https://") ||
            absoluteString.hasPrefix("www")
    }

    /// A  `String` without the schema (e.g., removes `https://` from `https://example.com`).
    var withoutSchema: String {
        guard let schemeEnd = absoluteString.range(of: "://")?.upperBound else {
            // If no schema is found, return the entire string
            return absoluteString
        }
        // Extract the substring starting after the "://"
        return String(absoluteString[schemeEnd...])
    }

    /// Computed property returning path to URL
    var posixPath: String {
        if #available(macOS 13.0, *) {
            self.path(percentEncoded: false)
        } else {
            path.removingPercentEncoding ?? path
        }
    }
}

extension View {
    /// Function to generate conversation as a SwiftUI `Image`
    func generateImage(
        scale: CGFloat = 2.0
    ) -> Image? {
        // Render and save
        let renderer: ImageRenderer<some View> = ImageRenderer(
            content: self
        )
        renderer.scale = scale
        guard let cgImage: CGImage = renderer.cgImage else {
            return nil
        }
        #if os(macOS)
            return Image(nsImage: NSImage(cgImage: cgImage, size: .zero))
        #else
            return Image(uiImage: UIImage(cgImage: cgImage))
        #endif
    }
}

// Simple wrapper view that handles the MainActor isolation
public struct LaTeXWrapper: View {
    let latexString: String
    @State private var isReady: Bool = false

    public var body: some View {
        ZStack {
            if isReady {
                LaTeX(latexString)
                    .blockMode(.alwaysInline)
                    .errorMode(.error)
                    .renderingStyle(.original)
                    .parsingMode(.onlyEquations)
                    .renderingAnimation(.easeIn)
                    .renderingStyle(.original)
                    .imageRenderingMode(.template)
            } else {
                Color.paletteClear
                    .onAppear {
                        isReady = true
                    }
            }
        }
    }
}

extension String {
    // swiftlint:disable line_length
    /// Function to convert LaTeX within a string into a Markdown image block
    /// containing a URL-encoded version
    func convertLaTeX() -> String {
        // Improved single regex pattern that better handles inline formulas
        let pattern: String = "(\\\\\\[(?:.|\\s)*?\\\\\\])|(\\$\\$(?:.|\\s)*?\\$\\$)|(\\\\\\((?:.|\\s)*?\\\\\\))|(\\$(?:(?:\\\\\\$)|[^$])*?\\$)"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return self
        }

        let mutableText: NSMutableString = NSMutableString(string: self)
        let matches: [NSTextCheckingResult] = regex.matches(
            in: self,
            options: [],
            range: NSRange(location: 0, length: mutableText.length)
        )

        // Iterate backwards so that range replacements don't affect upcoming ranges.
        for match in matches.reversed() {
            let fullRange: NSRange = match.range(at: 0)
            guard let range = Range(fullRange, in: self) else { continue }

            // Capture the entire LaTeX string (including delimiters).
            let rawLaTeX: String = String(self[range])

            // Determine if this is a block LaTeX expression.
            let isBlock: Bool = rawLaTeX.hasPrefix("\\[") || rawLaTeX.hasPrefix("$$")

            // Check for new lines in inline LaTeX, which is not allowed
            if rawLaTeX.contains("\n"), !isBlock {
                continue
            }

            // Replace \text{} with \mathrm{} to avoid rendering issues
            let textReplacedLaTeX: String = rawLaTeX.replacingOccurrences(
                of: "\\text{",
                with: "\\mathrm{"
            )

            // Remove newlines and extra spaces.
            let stripped: String = textReplacedLaTeX
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Percent-encode the full, stripped LaTeX expression.
            var allowed: CharacterSet = CharacterSet.alphanumerics
            allowed.insert(charactersIn: ".-_~")
            let encoded: String = stripped.addingPercentEncoding(
                withAllowedCharacters: allowed
            ) ?? ""

            // Compose the Markdown image. Block LaTeX gets newlines before and after.
            let replacement: String = (isBlock ? "\n" : "") + "![](latex://\(encoded))" +
                (isBlock ? "\n" : "")
            regex.replaceMatches(
                in: mutableText,
                options: [],
                range: fullRange,
                withTemplate: replacement
            )
        }

        return mutableText as String
    }
    // swiftlint:enable line_length
}
