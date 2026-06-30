import AppKit
import SwiftUI
import MarkdownView

enum QMarkMarkdownPreviewSource {
    case text(String)
    case streaming(StreamingMarkdownSource)
}

struct QMarkMarkdownPreview: View {
    let source: QMarkMarkdownPreviewSource
    let isDark: Bool
    let baseURL: URL?
    let scrollPercentage: CGFloat
    let onScrollChange: (CGFloat) -> Void
    let scrollSyncEnabled: Bool

    @State private var scrollPosition = ScrollPosition()
    @State private var scrollState = QMarkMarkdownScrollState()

    init(
        markdown: String,
        isDark: Bool = false,
        baseURL: URL? = nil,
        scrollPercentage: CGFloat = 0,
        onScrollChange: @escaping (CGFloat) -> Void = { _ in },
        scrollSyncEnabled: Bool = false
    ) {
        self.init(
            source: .text(markdown),
            isDark: isDark,
            baseURL: baseURL,
            scrollPercentage: scrollPercentage,
            onScrollChange: onScrollChange,
            scrollSyncEnabled: scrollSyncEnabled
        )
    }

    init(
        source: QMarkMarkdownPreviewSource,
        isDark: Bool = false,
        baseURL: URL? = nil,
        scrollPercentage: CGFloat = 0,
        onScrollChange: @escaping (CGFloat) -> Void = { _ in },
        scrollSyncEnabled: Bool = false
    ) {
        self.source = source
        self.isDark = isDark
        self.baseURL = baseURL
        self.scrollPercentage = scrollPercentage
        self.onScrollChange = onScrollChange
        self.scrollSyncEnabled = scrollSyncEnabled
    }

    @ViewBuilder
    var body: some View {
        if scrollSyncEnabled {
            basePreview
                .scrollPosition($scrollPosition)
                .onScrollGeometryChange(for: QMarkMarkdownScrollMetrics.self) { geometry in
                    QMarkMarkdownScrollMetrics(geometry)
                } action: { oldMetrics, newMetrics in
                    handleScrollMetricsChange(from: oldMetrics, to: newMetrics)
                }
                .onChange(of: scrollPercentage) {
                    applyExternalScroll(scrollPercentage)
                }
                .onDisappear {
                    scrollState.cancelTasks()
                }
        } else {
            basePreview
        }
    }

    private var basePreview: some View {
        ScrollView {
            renderedContent
                .frame(maxWidth: .infinity, alignment: .leading)
            .markdownMathRenderingEnabled()
            .markdownLinksUnderlined()
            .markdownTableStyle(.github)
            .markdownBlockQuoteStyle(.github)
            .markdownCodeBlockStyle(.default)
            .modifier(QMarkMarkdownBaseURLModifier(baseURL: baseURL))
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .environment(\.colorScheme, isDark ? .dark : .light)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private var renderedContent: some View {
        switch source {
        case .text(let markdown):
            MarkdownReader(markdown) { parseResult in
                MarkdownView(parseResult)
            }
        case .streaming(let source):
            StreamingMarkdownReader(source) { parseResult in
                MarkdownView(parseResult)
            }
        }
    }

    @MainActor
    private func handleScrollMetricsChange(
        from oldMetrics: QMarkMarkdownScrollMetrics,
        to newMetrics: QMarkMarkdownScrollMetrics
    ) {
        scrollState.metrics = newMetrics

        if abs(oldMetrics.maxY - newMetrics.maxY) > QMarkMarkdownScrollMetrics.pointTolerance {
            applyExternalScroll(scrollPercentage, force: true)
        }

        guard scrollState.isApplyingExternalScroll == false,
              newMetrics.maxY > 0,
              abs(oldMetrics.percentage - newMetrics.percentage) > QMarkMarkdownScrollMetrics.percentageTolerance
        else {
            return
        }

        scrollState.scheduleReport(newMetrics.percentage, onScrollChange: onScrollChange)
    }

    @MainActor
    private func applyExternalScroll(_ percentage: CGFloat, force: Bool = false) {
        guard scrollSyncEnabled else { return }

        let clampedPercentage = QMarkMarkdownScrollMetrics.clampedPercentage(percentage)
        let metrics = scrollState.metrics
        guard metrics.maxY > 0 else { return }

        let targetY = metrics.maxY * clampedPercentage
        guard force || abs(metrics.offsetY - targetY) > QMarkMarkdownScrollMetrics.pointTolerance else { return }

        scrollState.isApplyingExternalScroll = true
        scrollPosition.scrollTo(y: targetY)

        scrollState.releaseExternalScrollTask?.cancel()
        scrollState.releaseExternalScrollTask = Task { @MainActor [scrollState] in
            try? await Task.sleep(for: .milliseconds(120))
            scrollState.isApplyingExternalScroll = false
        }
    }
}

@MainActor
private final class QMarkMarkdownScrollState {
    var metrics = QMarkMarkdownScrollMetrics.empty
    var isApplyingExternalScroll = false
    var releaseExternalScrollTask: Task<Void, Never>?

    private var pendingReportPercentage: CGFloat?
    private var reportTask: Task<Void, Never>?
    private var lastReportedPercentage: CGFloat?

    func scheduleReport(_ percentage: CGFloat, onScrollChange: @escaping (CGFloat) -> Void) {
        let clampedPercentage = QMarkMarkdownScrollMetrics.clampedPercentage(percentage)

        if let lastReportedPercentage,
           abs(lastReportedPercentage - clampedPercentage) <= QMarkMarkdownScrollMetrics.percentageTolerance {
            return
        }

        pendingReportPercentage = clampedPercentage

        guard reportTask == nil else { return }
        reportTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(16))
            guard let self, let pendingReportPercentage else { return }

            self.pendingReportPercentage = nil
            self.reportTask = nil
            self.lastReportedPercentage = pendingReportPercentage
            onScrollChange(pendingReportPercentage)
        }
    }

    func cancelTasks() {
        releaseExternalScrollTask?.cancel()
        releaseExternalScrollTask = nil
        reportTask?.cancel()
        reportTask = nil
        pendingReportPercentage = nil
        isApplyingExternalScroll = false
    }
}

private struct QMarkMarkdownBaseURLModifier: ViewModifier {
    let baseURL: URL?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let baseURL {
            content.markdownBaseURL(baseURL)
        } else {
            content
        }
    }
}

private struct QMarkMarkdownScrollMetrics: Equatable {
    static let empty = QMarkMarkdownScrollMetrics(
        offsetY: 0,
        maxY: 0,
        percentage: 0
    )
    static let percentageTolerance: CGFloat = 0.0001
    static let pointTolerance: CGFloat = 1

    let offsetY: CGFloat
    let maxY: CGFloat
    let percentage: CGFloat

    init(_ geometry: ScrollGeometry) {
        let offsetY = max(0, geometry.contentOffset.y)
        let maxY = max(0, geometry.contentSize.height - geometry.containerSize.height)

        self.offsetY = offsetY
        self.maxY = maxY
        self.percentage = maxY > 0 ? Self.clampedPercentage(offsetY / maxY) : 0
    }

    private init(
        offsetY: CGFloat,
        maxY: CGFloat,
        percentage: CGFloat
    ) {
        self.offsetY = offsetY
        self.maxY = maxY
        self.percentage = percentage
    }

    static func clampedPercentage(_ percentage: CGFloat) -> CGFloat {
        max(0, min(1, percentage))
    }
}
