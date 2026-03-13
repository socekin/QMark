import Cocoa
import QuickLookUI
import WebKit

class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {

    private var webView: WKWebView!

    override func loadView() {
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        // Hide WebView until new content loads to avoid flicker
        webView.isHidden = true

        // Read Markdown file
        guard let markdownData = try? Data(contentsOf: url),
              let markdownText = String(data: markdownData, encoding: .utf8) else {
            handler(CocoaError(.fileReadCorruptFile))
            return
        }

        // Load SharedRenderer template
        guard let templateURL = Bundle(for: type(of: self)).url(
            forResource: "template",
            withExtension: "html",
            subdirectory: "SharedRenderer"
        ) else {
            handler(CocoaError(.fileReadNoSuchFile))
            return
        }

        // Load template page
        webView.loadFileURL(templateURL, allowingReadAccessTo: templateURL.deletingLastPathComponent())

        // Render Markdown after page loads
        let coordinator = QuickLookCoordinator(markdownText: markdownText, completionHandler: handler)
        webView.navigationDelegate = coordinator
        objc_setAssociatedObject(self, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN)
    }
}

private class QuickLookCoordinator: NSObject, WKNavigationDelegate {
    let markdownText: String
    let completionHandler: (Error?) -> Void

    init(markdownText: String, completionHandler: @escaping (Error?) -> Void) {
        self.markdownText = markdownText
        self.completionHandler = completionHandler
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.callAsyncJavaScript(
            "await renderMarkdown(markdown)",
            arguments: ["markdown": markdownText],
            in: nil,
            in: .page
        ) { [weak self] result in
            webView.isHidden = false
            switch result {
            case .success:
                self?.completionHandler(nil)
            case .failure(let error):
                self?.completionHandler(error)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completionHandler(error)
    }
}
