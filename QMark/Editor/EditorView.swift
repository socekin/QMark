import OSLog
import SwiftUI
import WebKit

struct EditorView: NSViewRepresentable {
    @ObservedObject var document: MarkdownDocument
    var isDark: Bool = false
    var scrollPercentage: CGFloat = 0
    var onTextChange: ((String) -> Void)?
    var onScrollChange: ((CGFloat) -> Void)?

    func makeNSView(context: Context) -> CleanWebView {
        let signpostID = OSSignpostID(log: QMarkPerformanceLog.pointsOfInterest)
        os_signpost(
            .begin,
            log: QMarkPerformanceLog.pointsOfInterest,
            name: "EditorView.makeNSView",
            signpostID: signpostID
        )
        defer {
            os_signpost(
                .end,
                log: QMarkPerformanceLog.pointsOfInterest,
                name: "EditorView.makeNSView",
                signpostID: signpostID
            )
        }

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // 注册 JS → Swift 消息处理
        let contentController = config.userContentController
        contentController.add(context.coordinator, name: "editorReady")
        contentController.add(context.coordinator, name: "contentChanged")
        contentController.add(context.coordinator, name: "scrollChanged")

        let webView = CleanWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView

        // 加载编辑器 HTML
        if let editorURL = Bundle.main.url(
            forResource: "editor",
            withExtension: "html",
            subdirectory: "EditorRenderer"
        ) {
            webView.loadFileURL(
                editorURL,
                allowingReadAccessTo: editorURL.deletingLastPathComponent()
            )
        }

        return webView
    }

    func updateNSView(_ webView: CleanWebView, context: Context) {
        context.coordinator.syncIfNeeded(document.text)
        context.coordinator.refreshThemeIfNeeded(isDark, webView: webView)
        context.coordinator.syncScrollIfNeeded(scrollPercentage)
    }

    static func dismantleNSView(_ webView: CleanWebView, coordinator: Coordinator) {
        let controller = webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: "editorReady")
        controller.removeScriptMessageHandler(forName: "contentChanged")
        controller.removeScriptMessageHandler(forName: "scrollChanged")
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler {
        let parent: EditorView
        weak var webView: WKWebView?
        private var isEditorReady = false
        private var pendingContent: String?
        private var lastSentContent: String?
        private var isSyncingFromJS = false
        private var lastIsDark: Bool?
        private var lastAppliedScrollPercentage: CGFloat?
        private var lastRequestedScrollPercentage: CGFloat?
        private var pendingScrollPercentage: CGFloat?
        private let scrollTolerance: CGFloat = 0.0001

        init(_ parent: EditorView) {
            self.parent = parent
            super.init()
        }

        // MARK: - Content Sync

        /// 当编辑器就绪后，发送初始内容
        private func sendContent(_ text: String) {
            guard isEditorReady, let webView = webView else {
                pendingContent = text
                return
            }
            lastSentContent = text
            // callAsyncJavaScript 将 arguments 注入为函数参数，此处 "text" 是注入的参数名
            webView.callAsyncJavaScript(
                "setContent(text)",
                arguments: ["text": text],
                in: nil,
                in: .page,
                completionHandler: nil
            )
        }

        /// 主动通知编辑器切换主题（不依赖 matchMedia change 事件）
        func refreshThemeIfNeeded(_ isDark: Bool, webView: WKWebView) {
            guard isDark != lastIsDark else { return }
            lastIsDark = isDark
            // 直接设置 WKWebView 外观
            webView.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
            // 同时通过 JS 通知 CodeMirror 切换主题
            guard isEditorReady else { return }
            webView.evaluateJavaScript("setTheme(\(isDark))")
        }

        /// 处理外部修改（如文件 revert）— 从 updateNSView 调用
        func syncIfNeeded(_ text: String) {
            guard !isSyncingFromJS else { return }
            guard text != lastSentContent else { return }
            sendContent(text)
        }

        // MARK: - WKScriptMessageHandler

        nonisolated func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            Task { @MainActor in
                handleMessage(message)
            }
        }

        private func handleMessage(_ message: WKScriptMessage) {
            switch message.name {
            case "editorReady":
                isEditorReady = true
                // 发送初始内容或缓存的内容
                let content = pendingContent ?? parent.document.text
                pendingContent = nil
                sendContent(content)
                if let pendingScrollPercentage {
                    self.pendingScrollPercentage = nil
                    syncScrollIfNeeded(pendingScrollPercentage)
                }

            case "contentChanged":
                guard let text = message.body as? String else { return }
                isSyncingFromJS = true
                lastSentContent = text
                parent.document.text = text
                parent.onTextChange?(text)
                isSyncingFromJS = false

            case "scrollChanged":
                if let percentage = message.body as? Double {
                    let clampedPercentage = Self.clampedPercentage(CGFloat(percentage))
                    lastAppliedScrollPercentage = clampedPercentage
                    lastRequestedScrollPercentage = clampedPercentage
                    parent.onScrollChange?(clampedPercentage)
                }

            default:
                break
            }
        }

        func syncScrollIfNeeded(_ percentage: CGFloat) {
            let clampedPercentage = Self.clampedPercentage(percentage)
            guard isEditorReady, let webView else {
                pendingScrollPercentage = clampedPercentage
                return
            }

            if let lastAppliedScrollPercentage,
               abs(lastAppliedScrollPercentage - clampedPercentage) <= scrollTolerance {
                return
            }
            if let lastRequestedScrollPercentage,
               abs(lastRequestedScrollPercentage - clampedPercentage) <= scrollTolerance {
                return
            }

            lastRequestedScrollPercentage = clampedPercentage
            webView.callAsyncJavaScript(
                "setScrollPercentage(percentage)",
                arguments: ["percentage": Double(clampedPercentage)],
                in: nil,
                in: .page,
                completionHandler: { [weak self] result in
                    Task { @MainActor in
                        guard let self else { return }

                        if let lastRequestedScrollPercentage = self.lastRequestedScrollPercentage,
                           abs(lastRequestedScrollPercentage - clampedPercentage) <= self.scrollTolerance {
                            self.lastRequestedScrollPercentage = nil
                        }

                        guard case .success(let value) = result,
                              Self.booleanResult(from: value)
                        else {
                            return
                        }

                        self.lastAppliedScrollPercentage = clampedPercentage
                    }
                }
            )
        }

        private static func clampedPercentage(_ percentage: CGFloat) -> CGFloat {
            max(0, min(1, percentage))
        }

        private static func booleanResult(from value: Any?) -> Bool {
            if let value = value as? Bool {
                return value
            }
            if let value = value as? NSNumber {
                return value.boolValue
            }
            return false
        }
    }
}
