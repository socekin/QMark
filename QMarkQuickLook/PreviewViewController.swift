import Cocoa
import MarkdownView
import QuickLookUI
import SwiftUI

class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {
    private var previewConstraints: [NSLayoutConstraint] = []
    private var streamingTask: Task<Void, Never>?

    deinit {
        streamingTask?.cancel()
    }

    override func loadView() {
        view = NSView()
    }

    func preparePreviewOfFile(
        at url: URL,
        completionHandler handler: @escaping (Error?) -> Void
    ) {
        QMarkPerformanceLog.logger.info("Quick Look prepare started")
        streamingTask?.cancel()

        let source = StreamingMarkdownSource()

        let preview = QMarkMarkdownPreview(
            source: .streaming(source),
            isDark: isDarkAppearance,
            baseURL: url.deletingLastPathComponent()
        )
        .environment(\.openURL, OpenURLAction { _ in
            .discarded
        })

        let hostingView = NSHostingView(rootView: preview)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        // Keep the controller root view stable because Quick Look's ViewBridge owns it after loadView.
        NSLayoutConstraint.deactivate(previewConstraints)
        view.subviews.forEach { $0.removeFromSuperview() }
        view.addSubview(hostingView)
        previewConstraints = [
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ]
        NSLayoutConstraint.activate(previewConstraints)

        streamingTask = Task.detached(priority: .userInitiated) { [url, source] in
            await Self.streamFile(at: url, into: source)
        }

        handler(nil)
    }

    private var isDarkAppearance: Bool {
        view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private static func streamFile(at url: URL, into source: StreamingMarkdownSource) async {
        let chunkSize = 256 * 1024
        var accumulatedData = Data()

        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer {
                try? fileHandle.close()
            }

            while Task.isCancelled == false {
                guard let chunk = try fileHandle.read(upToCount: chunkSize),
                      chunk.isEmpty == false
                else {
                    break
                }

                accumulatedData.append(chunk)
                let text = String(decoding: accumulatedData, as: UTF8.self)
                await MainActor.run {
                    source.text = text
                }
                await Task.yield()
            }
        } catch {
            QMarkPerformanceLog.logger.error("Quick Look streaming failed")
        }

        await MainActor.run {
            source.finishStreaming()
        }
    }
}
