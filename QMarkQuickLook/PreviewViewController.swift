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

    /// 构建自包含 HTML，内联所有 JS/CSS 和插件，与 APP 预览渲染一致
    private func buildSelfContainedHTML(markdown: String) -> String {
        let bundle = Bundle(for: type(of: self))
        let dir = "SharedRenderer"

        // 核心库
        let markdownItJS = readBundleFile(bundle, dir: dir, name: "libs/markdown-it.min", ext: "js")
        let highlightJS = readBundleFile(bundle, dir: dir, name: "libs/highlight.min", ext: "js")
        let katexJS = readBundleFile(bundle, dir: dir, name: "libs/katex.min", ext: "js")
        let mermaidJS = readBundleFile(bundle, dir: dir, name: "libs/mermaid.min", ext: "js")

        // markdown-it 插件
        let footnoteJS = readBundleFile(bundle, dir: dir, name: "libs/markdown-it-footnote.min", ext: "js")
        let subJS = readBundleFile(bundle, dir: dir, name: "libs/markdown-it-sub.min", ext: "js")
        let supJS = readBundleFile(bundle, dir: dir, name: "libs/markdown-it-sup.min", ext: "js")
        let markJS = readBundleFile(bundle, dir: dir, name: "libs/markdown-it-mark.min", ext: "js")
        let deflistJS = readBundleFile(bundle, dir: dir, name: "libs/markdown-it-deflist.min", ext: "js")
        let taskListsJS = readBundleFile(bundle, dir: dir, name: "libs/markdown-it-task-lists.min", ext: "js")
        let texmathJS = readBundleFile(bundle, dir: dir, name: "libs/markdown-it-texmath", ext: "js")
        let anchorJS = readBundleFile(bundle, dir: dir, name: "libs/markdown-it-anchor.min", ext: "js")
        let tocJS = readBundleFile(bundle, dir: dir, name: "libs/markdown-it-toc-done-right.min", ext: "js")

        // CSS
        let styleCSS = readBundleFile(bundle, dir: dir, name: "style", ext: "css")
        let hljsLightCSS = readBundleFile(bundle, dir: dir, name: "libs/github.min", ext: "css")
        let hljsDarkCSS = readBundleFile(bundle, dir: dir, name: "libs/github-dark.min", ext: "css")
        let katexCSS = readBundleFile(bundle, dir: dir, name: "libs/katex.min", ext: "css")

        // 使用 Base64 编码传递 Markdown 内容，避免 JS 字符串转义问题
        let base64Markdown = Data(markdown.utf8).base64EncodedString()

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>\(hljsLightCSS)</style>
            <style id="hljs-dark" media="(prefers-color-scheme: dark)">\(hljsDarkCSS)</style>
            <style>\(katexCSS)</style>
            <style>\(styleCSS)</style>
            <script>\(markdownItJS)</script>
            <script>\(highlightJS)</script>
            <script>\(katexJS)</script>
            <script>\(footnoteJS)</script>
            <script>\(subJS)</script>
            <script>\(supJS)</script>
            <script>\(markJS)</script>
            <script>\(deflistJS)</script>
            <script>\(taskListsJS)</script>
            <script>\(texmathJS)</script>
            <script>\(anchorJS)</script>
            <script>\(tocJS)</script>
            <script>\(mermaidJS)</script>
        </head>
        <body>
            <article id="content"></article>
            <script>
            (function() {
                // Base64 解码 Markdown 内容
                var b64 = "\(base64Markdown)";
                var bytes = Uint8Array.from(atob(b64), function(c) { return c.charCodeAt(0); });
                var text = new TextDecoder().decode(bytes);

                var md = window.markdownit({
                    html: false,
                    linkify: true,
                    typographer: true,
                    highlight: function(str, lang) {
                        if (lang === 'mermaid') {
                            return '';
                        }
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

                md.use(window.markdownitFootnote);
                md.use(window.markdownitSub);
                md.use(window.markdownitSup);
                md.use(window.markdownitMark);
                md.use(window.markdownitDeflist);
                md.use(window.markdownitTaskLists, { enabled: true });
                if (window.texmath && window.katex) {
                    md.use(window.texmath, { engine: katex, delimiters: 'dollars' });
                }
                if (window.markdownItAnchor) { md.use(window.markdownItAnchor); }
                if (window.markdownItTocDoneRight) { md.use(window.markdownItTocDoneRight); }

                document.getElementById('content').innerHTML = md.render(text);

                // Mermaid 后处理
                if (window.mermaid) {
                    mermaid.initialize({ startOnLoad: false, theme: 'default', securityLevel: 'strict' });
                    var blocks = document.querySelectorAll('pre > code.language-mermaid');
                    for (var i = 0; i < blocks.length; i++) {
                        var pre = blocks[i].parentElement;
                        var div = document.createElement('div');
                        div.className = 'mermaid';
                        div.textContent = blocks[i].textContent;
                        pre.replaceWith(div);
                    }
                    var mermaidDivs = document.querySelectorAll('.mermaid');
                    if (mermaidDivs.length > 0) {
                        try { mermaid.run({ querySelector: '.mermaid' }); } catch(e) {}
                    }
                }
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

}
