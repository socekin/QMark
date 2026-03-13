import SwiftUI

@main
struct QMarkApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { MarkdownDocument() }) { file in
            ContentView(document: file.document)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
    }
}
