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
        guard let markdownData = try? Data(contentsOf: url),
              let markdownText = String(data: markdownData, encoding: .utf8) else {
            handler(NSError(domain: "QMarkQuickLook", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Cannot read file"
            ]))
            return
        }

        let html = buildSelfContainedHTML(markdown: markdownText)
        webView.loadHTMLString(html, baseURL: nil)
        handler(nil)
    }

    /// 构建自包含 HTML，内联核心 JS/CSS，无外部文件依赖
    private func buildSelfContainedHTML(markdown: String) -> String {
        let bundle = Bundle(for: type(of: self))
        let dir = "SharedRenderer"

        let markdownItJS = readBundleFile(bundle, dir: dir, name: "libs/markdown-it.min", ext: "js")
        let highlightJS = readBundleFile(bundle, dir: dir, name: "libs/highlight.min", ext: "js")
        let styleCSS = readBundleFile(bundle, dir: dir, name: "style", ext: "css")
        let hljsLightCSS = readBundleFile(bundle, dir: dir, name: "libs/github.min", ext: "css")
        let hljsDarkCSS = readBundleFile(bundle, dir: dir, name: "libs/github-dark.min", ext: "css")

        let escapedMarkdown = escapeForJSString(markdown)

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>\(hljsLightCSS)</style>
            <style id="hljs-dark" media="(prefers-color-scheme: dark)">\(hljsDarkCSS)</style>
            <style>\(styleCSS)</style>
            <script>\(markdownItJS)</script>
            <script>\(highlightJS)</script>
        </head>
        <body>
            <article id="content"></article>
            <script>
            (function() {
                var md = window.markdownit({
                    html: false,
                    linkify: true,
                    typographer: true,
                    highlight: function(str, lang) {
                        if (lang && hljs.getLanguage(lang)) {
                            try {
                                return '<pre class="hljs"><code>' +
                                    hljs.highlight(str, { language: lang, ignoreIllegals: true }).value +
                                    '</code></pre>';
                            } catch (_) {}
                        }
                        return '<pre class="hljs"><code>' + md.utils.escapeHtml(str) + '</code></pre>';
                    }
                });
                var text = "\(escapedMarkdown)";
                document.getElementById('content').innerHTML = md.render(text);
            })();
            </script>
        </body>
        </html>
        """
    }

    private func readBundleFile(_ bundle: Bundle, dir: String, name: String, ext: String) -> String {
        guard let url = bundle.url(forResource: name, withExtension: ext, subdirectory: dir),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return content
    }

    private func escapeForJSString(_ str: String) -> String {
        var result = ""
        result.reserveCapacity(str.count + str.count / 10)
        for char in str {
            switch char {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case "\u{2028}": result += "\\u2028"
            case "\u{2029}": result += "\\u2029"
            default: result.append(char)
            }
        }
        return result
    }
}
