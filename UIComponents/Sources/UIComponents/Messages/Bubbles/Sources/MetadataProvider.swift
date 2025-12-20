import Foundation

// MARK: - MetadataProvider

@preconcurrency
@MainActor
public final class MetadataProvider: ObservableObject {
    @Published private(set) var metadata: WebsiteMetadata = .init()
    private var task: URLSessionDataTask?

    nonisolated private static let minRanges: Int = 2

    deinit {
        task?.cancel()
    }

    func fetchMetadata(for url: URL) {
        // Try favicon by convention first
        if let host = url.host {
            metadata.faviconURL = URL(string: "https://\(host)/favicon.ico")
        }

        // Setup request with a short timeout
        var request: URLRequest = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = SourceViewConstants.requestTimeoutInterval
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        task = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard
                let data,
                let htmlString = String(data: data, encoding: .utf8),
                error == nil
            else {
                return
            }

            let extractedMetadata: WebsiteMetadata = Self.extractMetadata(
                from: htmlString,
                baseURL: url
            )

            DispatchQueue.main.async { [weak self] in
                self?.metadata = extractedMetadata
            }
        }

        task?.resume()
    }

    nonisolated private static func extractMetadata(
        from html: String,
        baseURL: URL
    ) -> WebsiteMetadata {
        var metadata: WebsiteMetadata = WebsiteMetadata()

        // Extract title
        metadata.title = extractContent(from: html, pattern: "<title[^>]*>(.*?)</title>") ?? ""

        // Extract description from meta tags
        metadata.description = extractContent(
            from: html,
            pattern: "<meta\\s+name=[\"']description[\"']\\s+content=[\"'](.*?)[\"']"
        ) ?? ""

        // Extract Open Graph metadata
        let ogTitle: String? = extractContent(
            from: html,
            pattern: "<meta\\s+property=[\"']og:title[\"']\\s+content=[\"'](.*?)[\"']"
        )
        let ogDescription: String? = extractContent(
            from: html,
            pattern: "<meta\\s+property=[\"']og:description[\"']\\s+content=[\"'](.*?)[\"']"
        )

        // Prefer Open Graph if available
        if let ogTitle, !ogTitle.isEmpty {
            metadata.title = ogTitle
        }

        if let ogDescription, !ogDescription.isEmpty {
            metadata.description = ogDescription
        }

        // Extract favicon
        if let faviconPath: String = extractContent(
            from: html,
            pattern: "<link[^>]*rel=[\"'](?:shortcut )?icon[\"'][^>]*href=[\"'](.*?)[\"']"
        ) {
            metadata.faviconURL = resolveURL(path: faviconPath, baseURL: baseURL)
        }

        // Extract Open Graph image
        if let ogImagePath: String = extractContent(
            from: html,
            pattern: "<meta\\s+property=[\"']og:image[\"']\\s+content=[\"'](.*?)[\"']"
        ) {
            metadata.ogImage = resolveURL(path: ogImagePath, baseURL: baseURL)
        }

        return metadata
    }

    nonisolated private static func extractContent(from html: String, pattern: String) -> String? {
        guard
            let regex: NSRegularExpression = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            )
        else {
            return nil
        }

        let range: NSRange = NSRange(html.startIndex ..< html.endIndex, in: html)
        guard let match: NSTextCheckingResult = regex.firstMatch(
            in: html,
            options: [],
            range: range
        ),
            match.numberOfRanges >= minRanges,
            let contentRange: Range<String.Index> = Range(match.range(at: 1), in: html)
        else {
            return nil
        }

        let content: String = String(html[contentRange])
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func resolveURL(path: String, baseURL: URL) -> URL? {
        // Check if it's already an absolute URL
        if let url = URL(string: path), url.scheme != nil {
            return url
        }

        // Handle relative paths
        return URL(string: path, relativeTo: baseURL)
    }
}

// MARK: - Website Metadata Types

/// Represents metadata extracted from a website
public struct WebsiteMetadata {
    var title: String = ""
    var description: String = ""
    var faviconURL: URL?
    var ogImage: URL?
}
