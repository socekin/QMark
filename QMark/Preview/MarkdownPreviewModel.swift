import Foundation
import MarkdownView

@MainActor
final class MarkdownPreviewModel: ObservableObject {
    @Published private(set) var previewSource: QMarkMarkdownPreviewSource = .text("")

    private var pendingTask: Task<Void, Never>?
    private var pendingTaskID: UUID?
    private var streamingTask: Task<Void, Never>?

    func load(_ text: String) {
        pendingTask?.cancel()
        pendingTask = nil
        pendingTaskID = nil
        streamText(text)
    }

    func scheduleUpdate(_ text: String) {
        pendingTask?.cancel()
        let delay = Self.delay(forByteCount: text.utf8.count)
        let taskID = UUID()
        pendingTaskID = taskID

        pendingTask = Task { [weak self, taskID] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                guard self?.pendingTaskID == taskID else { return }
                self?.pendingTask = nil
                self?.pendingTaskID = nil
                self?.streamText(text)
            }
        }
    }

    private func streamText(_ text: String) {
        streamingTask?.cancel()

        let source = StreamingMarkdownSource()
        previewSource = .streaming(source)

        streamingTask = Task {
            await Self.stream(text, into: source)
        }
    }

    nonisolated private static func stream(_ text: String, into source: StreamingMarkdownSource) async {
        let chunkSize = 256 * 1024
        var index = text.startIndex
        var accumulated = ""

        while index < text.endIndex, Task.isCancelled == false {
            let next = text.index(index, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            accumulated += String(text[index..<next])
            await MainActor.run {
                source.text = accumulated
            }
            index = next
            await Task.yield()
        }

        await MainActor.run {
            source.finishStreaming()
        }
    }

    private static func delay(forByteCount byteCount: Int) -> Duration {
        switch byteCount {
        case ..<512_000:
            return .milliseconds(250)
        case ..<2_097_152:
            return .milliseconds(500)
        case ..<5_242_880:
            return .milliseconds(800)
        default:
            return .milliseconds(1200)
        }
    }
}
