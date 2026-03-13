import SwiftUI

@main
struct QMarkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: { MarkdownDocument() }) { file in
            ContentView(document: file.document)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            // 移除 Help 菜单
            CommandGroup(replacing: .help) {}
            // 移除 View > Toolbar 相关
            CommandGroup(replacing: .toolbar) {}
            // 移除 View > Sidebar
            CommandGroup(replacing: .sidebar) {}
            // 移除 Edit > Spelling/Grammar、Substitutions、Transformations、Speech
            CommandGroup(replacing: .textEditing) {}
            // 移除 File > Print
            CommandGroup(replacing: .printItem) {}
            // 移除 File > Import/Export
            CommandGroup(replacing: .importExport) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 直接从主菜单栏移除 Format 菜单（SwiftUI 的 CommandGroup 无法彻底移除）
        DispatchQueue.main.async {
            NSApp.mainMenu?.items.removeAll { $0.title == "Format" }
        }
    }
}
