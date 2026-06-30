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

        let fileHandle: FileHandle
        do {
            fileHandle = try FileHandle(forReadingFrom: url)
        } catch {
            handler(NSError(domain: "QMarkQuickLook", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Cannot read file"
            ]))
            return
        }

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

        streamingTask = Task.detached(priority: .userInitiated) { [fileHandle, source] in
            await Self.streamFile(fileHandle, into: source)
        }

        handler(nil)
    }

    private var isDarkAppearance: Bool {
        view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private static func streamFile(_ fileHandle: FileHandle, into source: StreamingMarkdownSource) async {
        let chunkSize = 256 * 1024
        var accumulatedText = ""
        var pendingBytes = Data()

        defer {
            try? fileHandle.close()
        }

        do {
            while Task.isCancelled == false {
                guard let chunk = try fileHandle.read(upToCount: chunkSize),
                      chunk.isEmpty == false
                else {
                    break
                }

                pendingBytes.append(chunk)
                let decodedChunk = decodeValidUTF8Prefix(from: pendingBytes)
                pendingBytes = decodedChunk.pendingBytes
                accumulatedText += decodedChunk.text

                await MainActor.run {
                    source.text = accumulatedText
                }
                await Task.yield()
            }
        } catch {
            QMarkPerformanceLog.logger.error("Quick Look streaming failed")
        }

        if pendingBytes.isEmpty == false {
            accumulatedText += String(decoding: pendingBytes, as: UTF8.self)
            await MainActor.run {
                source.text = accumulatedText
            }
        }

        await MainActor.run {
            source.finishStreaming()
        }
    }

    private static func decodeValidUTF8Prefix(from bytes: Data) -> (text: String, pendingBytes: Data) {
        let maxPendingByteCount = min(3, bytes.count)

        for pendingByteCount in 0...maxPendingByteCount {
            let textByteCount = bytes.count - pendingByteCount
            let textBytes = bytes.prefix(textByteCount)

            if let text = String(data: textBytes, encoding: .utf8) {
                return (text, Data(bytes.suffix(pendingByteCount)))
            }
        }

        return (String(decoding: bytes, as: UTF8.self), Data())
    }
}
