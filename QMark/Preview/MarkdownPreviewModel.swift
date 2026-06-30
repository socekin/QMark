import Foundation
import MarkdownView

@MainActor
final class MarkdownPreviewModel: ObservableObject {
    enum Mode {
        case immediate
        case debounced
    }

    @Published private(set) var markdown: String = ""

    private var pendingTask: Task<Void, Never>?

    func load(_ text: String) {
        pendingTask?.cancel()
        markdown = text
    }

    func scheduleUpdate(_ text: String) {
        pendingTask?.cancel()
        let delay = Self.delay(forByteCount: text.utf8.count)

        pendingTask = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                self?.markdown = text
            }
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
