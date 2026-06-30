import Cocoa
import QuickLookUI
import SwiftUI

class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {
    private var previewConstraints: [NSLayoutConstraint] = []

    override func loadView() {
        view = NSView()
    }

    func preparePreviewOfFile(
        at url: URL,
        completionHandler handler: @escaping (Error?) -> Void
    ) {
        guard let markdownData = try? Data(contentsOf: url),
              let markdownText = String(data: markdownData, encoding: .utf8)
        else {
            handler(NSError(domain: "QMarkQuickLook", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Cannot read file"
            ]))
            return
        }

        let preview = QMarkMarkdownPreview(
            markdown: markdownText,
            isDark: isDarkAppearance,
            baseURL: url.deletingLastPathComponent()
        )
        .environment(\.openURL, OpenURLAction { _ in
            .discarded
        })

        let hostingView = NSHostingView(rootView: preview)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        // Keep the controller root view stable because Quick Look's ViewBridge owns it after loadView.
        NSLayoutConstraint.deactivate(previewConstraints)
        view.subviews.forEach { $0.removeFromSuperview() }
        view.addSubview(hostingView)
        previewConstraints = [
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ]
        NSLayoutConstraint.activate(previewConstraints)

        handler(nil)
    }

    private var isDarkAppearance: Bool {
        view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
