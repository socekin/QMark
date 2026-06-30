import AppKit
import SwiftUI

struct PreviewView: View {
    let source: QMarkMarkdownPreviewSource
    let scrollPercentage: CGFloat
    let isDark: Bool

    init(
        source: QMarkMarkdownPreviewSource,
        scrollPercentage: CGFloat,
        isDark: Bool = false
    ) {
        self.source = source
        self.scrollPercentage = scrollPercentage
        self.isDark = isDark
    }

    init(
        markdown: String,
        scrollPercentage: CGFloat,
        isDark: Bool = false
    ) {
        self.init(
            source: .text(markdown),
            scrollPercentage: scrollPercentage,
            isDark: isDark
        )
    }

    var body: some View {
        QMarkMarkdownPreview(
            source: source,
            isDark: isDark
        )
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            return .handled
        })
    }
}
