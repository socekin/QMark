import Foundation

@MainActor
final class MarkdownPreviewModel: ObservableObject {
    @Published private(set) var markdown: String = ""

    private var pendingTask: Task<Void, Never>?
    private var pendingTaskID: UUID?

    func load(_ text: String) {
        pendingTask?.cancel()
        pendingTask = nil
        pendingTaskID = nil
        markdown = text
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
                self?.markdown = text
                self?.pendingTask = nil
                self?.pendingTaskID = nil
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
