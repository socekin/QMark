import Cocoa
import QuickLookUI
import SwiftUI

class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {
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

        view = NSHostingView(rootView: preview)
        handler(nil)
    }

    private var isDarkAppearance: Bool {
        view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
