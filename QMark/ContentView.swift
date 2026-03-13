import SwiftUI

struct ContentView: View {
    @ObservedObject var document: MarkdownDocument
    @State private var markdownText: String = ""
    @State private var scrollPercentage: CGFloat = 0

    var body: some View {
        HSplitView {
            // Left: Editor
            EditorView(
                document: document,
                onTextChange: { text in
                    markdownText = text
                },
                onScrollChange: { percentage in
                    scrollPercentage = percentage
                }
            )
            .frame(minWidth: 300)

            // Right: Preview
            PreviewView(
                markdown: markdownText,
                scrollPercentage: scrollPercentage
            )
            .frame(minWidth: 300)
        }
        .onAppear {
            markdownText = document.text
        }
        .frame(minWidth: 700, minHeight: 500)
        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
    }
}
