import SwiftUI
import WebKit

struct PreviewView: NSViewRepresentable {
    let markdown: String
    let scrollPercentage: CGFloat

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let bridge = PreviewBridge()
        bridge.register(in: config)
        bridge.onLinkClicked = { url in
            NSWorkspace.shared.open(url)
        }
        context.coordinator.bridge = bridge

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView

        // Load template.html
        if let templateURL = Bundle.main.url(forResource: "template", withExtension: "html", subdirectory: "SharedRenderer") {
            webView.loadFileURL(templateURL, allowingReadAccessTo: templateURL.deletingLastPathComponent())
        }

        // Wait for page load to render
        webView.navigationDelegate = context.coordinator

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator

        if coordinator.isPageLoaded {
            if coordinator.lastRenderedMarkdown != markdown {
                coordinator.lastRenderedMarkdown = markdown
                coordinator.bridge?.render(markdown: markdown, in: webView)
            }
            if coordinator.lastScrollPercentage != scrollPercentage {
                coordinator.lastScrollPercentage = scrollPercentage
                coordinator.bridge?.setScrollPercentage(scrollPercentage, in: webView)
            }
        } else {
            coordinator.pendingMarkdown = markdown
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var bridge: PreviewBridge?
        weak var webView: WKWebView?
        var isPageLoaded = false
        var pendingMarkdown: String?
        var lastRenderedMarkdown: String?
        var lastScrollPercentage: CGFloat = 0

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageLoaded = true
            if let markdown = pendingMarkdown {
                pendingMarkdown = nil
                lastRenderedMarkdown = markdown
                bridge?.render(markdown: markdown, in: webView)
            }
        }
    }
}
