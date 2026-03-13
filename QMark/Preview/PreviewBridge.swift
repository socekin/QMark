import WebKit

final class PreviewBridge: NSObject, WKScriptMessageHandler {

    var onRenderComplete: (() -> Void)?
    var onLinkClicked: ((URL) -> Void)?

    // Register JS -> Swift message handlers
    func register(in configuration: WKWebViewConfiguration) {
        let contentController = configuration.userContentController
        contentController.add(self, name: "renderComplete")
        contentController.add(self, name: "linkClicked")

        // Intercept link clicks, open in system browser
        let linkScript = WKUserScript(source: """
            document.addEventListener('click', function(e) {
                var target = e.target;
                while (target && target.tagName !== 'A') {
                    target = target.parentElement;
                }
                if (target && target.href && !target.href.startsWith('about:')) {
                    e.preventDefault();
                    window.webkit.messageHandlers.linkClicked.postMessage(target.href);
                }
            });
            """, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        contentController.addUserScript(linkScript)
    }

    // Render Markdown content
    func render(markdown: String, in webView: WKWebView) {
        webView.callAsyncJavaScript(
            "await renderMarkdown(markdown)",
            arguments: ["markdown": markdown],
            in: nil,
            in: .page
        ) { result in
            if case .failure(let error) = result {
                print("Render error: \(error.localizedDescription)")
            }
        }
    }

    // Set scroll position
    func setScrollPercentage(_ percentage: CGFloat, in webView: WKWebView) {
        webView.callAsyncJavaScript(
            "setScrollPercentage(percentage)",
            arguments: ["percentage": percentage],
            in: nil,
            in: .page,
            completionHandler: nil
        )
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        switch message.name {
        case "renderComplete":
            onRenderComplete?()
        case "linkClicked":
            if let urlString = message.body as? String,
               let url = URL(string: urlString) {
                onLinkClicked?(url)
            }
        default:
            break
        }
    }
}
