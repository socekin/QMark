import AppKit
import SwiftUI

struct PreviewView: View {
    let markdown: String
    let scrollPercentage: CGFloat
    var isDark: Bool = false

    var body: some View {
        QMarkMarkdownPreview(
            markdown: markdown,
            isDark: isDark
        )
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            return .handled
        })
    }
}
