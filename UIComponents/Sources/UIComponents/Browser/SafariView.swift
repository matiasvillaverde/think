import SwiftUI

#if os(iOS) || os(visionOS)
    import SafariServices

    /// A SwiftUI wrapper for SFSafariViewController to present web content in-app
    internal struct SafariView: UIViewControllerRepresentable {
        // MARK: - Properties

        let url: URL

        // MARK: - UIViewControllerRepresentable

        func makeUIViewController(context _: Context) -> SFSafariViewController {
            let configuration: SFSafariViewController.Configuration =
                SFSafariViewController.Configuration()
            configuration.entersReaderIfAvailable = false

            let safariViewController: SFSafariViewController = SFSafariViewController(
                url: url,
                configuration: configuration
            )

            #if !os(visionOS)
                configuration.barCollapsingEnabled = true
                // Style the Safari view
                safariViewController.preferredControlTintColor = UIColor.systemBlue
                safariViewController.dismissButtonStyle = .done
            #endif

            return safariViewController
        }

        func updateUIViewController(
            _: SFSafariViewController,
            context _: Context
        ) {
            // No updates needed
        }
    }

#elseif os(macOS)
    import WebKit

    /// A SwiftUI wrapper for WKWebView to present web content in-app on macOS
    internal struct SafariView: NSViewRepresentable {
        // MARK: - Properties

        let url: URL

        // MARK: - NSViewRepresentable

        func makeNSView(context: Context) -> WKWebView {
            let configuration: WKWebViewConfiguration = WKWebViewConfiguration()
            // JavaScript is enabled by default in WKWebView

            let webView: WKWebView = WKWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = context.coordinator

            let request: URLRequest = URLRequest(url: url)
            webView.load(request)

            return webView
        }

        func updateNSView(_: WKWebView, context _: Context) {
            // No updates needed
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        // MARK: - Coordinator

        class Coordinator: NSObject, WKNavigationDelegate {
            deinit {
                // Required deinit for SwiftLint
            }
        }
    }
#endif
