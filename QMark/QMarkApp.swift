import SwiftUI
import AppKit

@main
struct QMarkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let launchSceneRestorationBehavior: SceneRestorationBehavior

    init() {
        let allowsNativeRestoration = QMarkWindowRestorationPolicy.shouldEnableNativeSceneRestorationOnLaunch()
        launchSceneRestorationBehavior = allowsNativeRestoration ? .automatic : .disabled
        QMarkWindowRestorationPolicy.setApplePersistenceStateIgnored(!allowsNativeRestoration)
    }

    var body: some Scene {
        DocumentGroup(newDocument: { MarkdownDocument() }) { file in
            ContentView(document: file.document)
        }
        .restorationBehavior(launchSceneRestorationBehavior)
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About QMark") {
                    NSApp.activate(ignoringOtherApps: true)
                    AboutWindow.show()
                }
            }
            // Remove the Help menu.
            CommandGroup(replacing: .help) {}
            // Remove View > Toolbar commands.
            CommandGroup(replacing: .toolbar) {}
            // Remove View > Sidebar commands.
            CommandGroup(replacing: .sidebar) {}
            // Remove Edit > Spelling and text transformation commands.
            CommandGroup(replacing: .textEditing) {}
            // Remove File > Print.
            CommandGroup(replacing: .printItem) {}
            // Remove File > Import/Export.
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

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var isSystemTerminationPending = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        installWindowRestorationPolicy()
        QMarkWindowRestorationPolicy.setNativeSceneRestorationEnabledForNextLaunch(false)
        QMarkWindowRestorationPolicy.setApplePersistenceStateIgnored(true)

        // Remove the Format menu from the main menu because CommandGroup cannot remove it completely.
        DispatchQueue.main.async {
            NSApp.mainMenu?.items.removeAll { $0.title == "Format" }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let source = currentTerminationSource
        let isSystemTermination = source == .systemInitiated
        QMarkWindowRestorationPolicy.setNativeSceneRestorationEnabledForNextLaunch(isSystemTermination)
        QMarkWindowRestorationPolicy.setApplePersistenceStateIgnored(!isSystemTermination)
        applyRestorationPolicyToOpenWindows(for: source)
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    private var currentTerminationSource: QMarkTerminationSource {
        isSystemTerminationPending ? .systemInitiated : .userInitiated
    }

    private func installWindowRestorationPolicy() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceWillPowerOff(_:)),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    @objc private func workspaceWillPowerOff(_ notification: Notification) {
        isSystemTerminationPending = true
        QMarkWindowRestorationPolicy.setNativeSceneRestorationEnabledForNextLaunch(true)
        QMarkWindowRestorationPolicy.setApplePersistenceStateIgnored(false)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let isSystemTermination = currentTerminationSource == .systemInitiated
        QMarkWindowRestorationPolicy.setNativeSceneRestorationEnabledForNextLaunch(isSystemTermination)
        QMarkWindowRestorationPolicy.setApplePersistenceStateIgnored(!isSystemTermination)
        applyRestorationPolicy(to: window, for: currentTerminationSource)
    }

    private func applyRestorationPolicyToOpenWindows(for source: QMarkTerminationSource) {
        NSApp.windows.forEach { applyRestorationPolicy(to: $0, for: source) }
    }

    private func applyRestorationPolicy(to window: NSWindow, for source: QMarkTerminationSource) {
        let shouldKeepRestorable = QMarkWindowRestorationPolicy.shouldKeepDocumentWindowsRestorable(for: source)
        window.isRestorable = shouldKeepRestorable

        if shouldKeepRestorable {
            window.enableSnapshotRestoration()
        } else {
            window.disableSnapshotRestoration()
        }
    }

}
