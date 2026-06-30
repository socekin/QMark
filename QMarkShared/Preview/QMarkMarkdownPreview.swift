import AppKit
import SwiftUI
import MarkdownView

struct QMarkMarkdownPreview: View {
    let markdown: String
    let isDark: Bool
    let baseURL: URL?

    init(
        markdown: String,
        isDark: Bool = false,
        baseURL: URL? = nil
    ) {
        self.markdown = markdown
        self.isDark = isDark
        self.baseURL = baseURL
    }

    var body: some View {
        ScrollView {
            MarkdownReader(markdown) { parseResult in
                MarkdownView(parseResult)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .markdownMathRenderingEnabled()
            .markdownLinksUnderlined()
            .markdownTableStyle(.github)
            .markdownBlockQuoteStyle(.github)
            .markdownCodeBlockStyle(.default)
            .modifier(QMarkMarkdownBaseURLModifier(baseURL: baseURL))
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .environment(\.colorScheme, isDark ? .dark : .light)
        .textSelection(.enabled)
    }
}

private struct QMarkMarkdownBaseURLModifier: ViewModifier {
    let baseURL: URL?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let baseURL {
            content.markdownBaseURL(baseURL)
        } else {
            content
        }
    }
}
