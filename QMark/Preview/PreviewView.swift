import AppKit
import SwiftUI

struct PreviewView: View {
    let source: QMarkMarkdownPreviewSource
    let scrollPercentage: CGFloat
    let isDark: Bool
    let onScrollChange: (CGFloat) -> Void

    init(
        source: QMarkMarkdownPreviewSource,
        scrollPercentage: CGFloat,
        isDark: Bool = false,
        onScrollChange: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.source = source
        self.scrollPercentage = scrollPercentage
        self.isDark = isDark
        self.onScrollChange = onScrollChange
    }

    init(
        markdown: String,
        scrollPercentage: CGFloat,
        isDark: Bool = false,
        onScrollChange: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.init(
            source: .text(markdown),
            scrollPercentage: scrollPercentage,
            isDark: isDark,
            onScrollChange: onScrollChange
        )
    }

    var body: some View {
        QMarkMarkdownPreview(
            source: source,
            isDark: isDark,
            scrollPercentage: scrollPercentage,
            onScrollChange: onScrollChange,
            scrollSyncEnabled: true
        )
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            return .handled
        })
    }
}
