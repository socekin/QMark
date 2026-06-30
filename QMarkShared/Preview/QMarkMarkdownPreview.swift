import AppKit
import SwiftUI
import MarkdownView

enum QMarkMarkdownPreviewSource {
    case text(String)
    case streaming(StreamingMarkdownSource)
}

struct QMarkMarkdownPreview: View {
    let source: QMarkMarkdownPreviewSource
    let isDark: Bool
    let baseURL: URL?

    init(
        markdown: String,
        isDark: Bool = false,
        baseURL: URL? = nil
    ) {
        self.init(
            source: .text(markdown),
            isDark: isDark,
            baseURL: baseURL
        )
    }

    init(
        source: QMarkMarkdownPreviewSource,
        isDark: Bool = false,
        baseURL: URL? = nil
    ) {
        self.source = source
        self.isDark = isDark
        self.baseURL = baseURL
    }

    var body: some View {
        ScrollView {
            renderedContent
                .frame(maxWidth: .infinity, alignment: .leading)
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

    @ViewBuilder
    private var renderedContent: some View {
        switch source {
        case .text(let markdown):
            MarkdownReader(markdown) { parseResult in
                MarkdownView(parseResult)
            }
        case .streaming(let source):
            StreamingMarkdownReader(source) { parseResult in
                MarkdownView(parseResult)
            }
        }
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
