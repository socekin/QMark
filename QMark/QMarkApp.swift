import SwiftUI
import AppKit

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
            CommandGroup(replacing: .appInfo) {
                Button("About QMark") {
                    NSApp.activate(ignoringOtherApps: true)
                    AboutWindow.show()
                }
            }
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

// MARK: - About Window

@MainActor
final class AboutWindow {
    private static var windowController: NSWindowController?

    static func show() {
        if let wc = windowController {
            wc.window?.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About QMark"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AboutView())
        let wc = NSWindowController(window: window)
        windowController = wc
        wc.showWindow(nil)
    }
}

struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            Text("QMark")
                .font(.title.bold())

            Text("Version \(version) (\(build))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 20)

            Link("GitHub Repository", destination: URL(string: "https://github.com/socekin/QMark")!)
                .font(.callout)

            Link("@jayfx42", destination: URL(string: "https://x.com/jayfx42")!)
                .font(.callout)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 30)
        .frame(width: 300)
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
