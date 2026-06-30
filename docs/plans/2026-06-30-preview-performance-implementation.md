# Preview Performance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make QMark preview-first, keep opening and Quick Look fast for Markdown files below 5 MB, and restore bidirectional scroll synchronization without replacing the current CodeMirror editor.

**Architecture:** Keep the WKWebView and CodeMirror editor, but instantiate it only when editing is enabled. Move preview rendering behind a dedicated model that can debounce editor updates and stream initial Markdown into MarkdownView. Keep MarkdownView inside the native SwiftUI preview `ScrollView`, then use macOS 15 scroll geometry and scroll position APIs for preview offset observation and control.

**Tech Stack:** SwiftUI, AppKit, QuickLookUI, WebKit, CodeMirror 6, MarkdownView 3 `StreamingMarkdownReader`, XcodeGen, Swift Package Manager.

---

## Task 1: Add Local Performance Fixtures

**Files:**
- Create: `scripts/generate-markdown-fixtures.sh`
- Modify: `README.md`

**Step 1: Add the fixture generator**

Create `scripts/generate-markdown-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/tmp/perf"
mkdir -p "$OUT_DIR"

generate_file() {
  local target="$1"
  local size_bytes="$2"
  local block
  block=$'# Performance Fixture\n\nThis paragraph is generated for QMark preview performance testing.\n\n- Item one\n- Item two\n- Item three\n\n```swift\nlet value = "QMark"\nprint(value)\n```\n\n| Column | Value |\n| --- | --- |\n| Alpha | Beta |\n\n'

  : > "$target"
  while [ "$(wc -c < "$target")" -lt "$size_bytes" ]; do
    printf "%s" "$block" >> "$target"
  done
}

generate_file "$OUT_DIR/markdown-500kb.md" 512000
generate_file "$OUT_DIR/markdown-1mb.md" 1048576
generate_file "$OUT_DIR/markdown-5mb.md" 5242880
generate_file "$OUT_DIR/markdown-10mb.md" 10485760

ls -lh "$OUT_DIR"
```

Run:

```bash
chmod +x scripts/generate-markdown-fixtures.sh
scripts/generate-markdown-fixtures.sh
```

Expected: `tmp/perf` contains 500 KB, 1 MB, 5 MB, and 10 MB Markdown files.

**Step 2: Document the fixtures**

Add this short section to `README.md` under Verification:

````markdown
Generate local performance fixtures:

```bash
scripts/generate-markdown-fixtures.sh
```

Use the generated files in `tmp/perf/` for app and Quick Look smoke testing.
````

**Step 3: Verify**

Run:

```bash
scripts/generate-markdown-fixtures.sh
make build
```

Expected: fixture generation succeeds and the app builds.

**Step 4: Commit**

```bash
git add README.md scripts/generate-markdown-fixtures.sh
git commit -m "test: add markdown performance fixtures"
```

## Task 2: Add Lightweight Performance Logging

**Files:**
- Create: `QMarkShared/Performance/QMarkPerformanceLog.swift`
- Modify: `QMark/Editor/EditorView.swift`
- Modify: `QMarkQuickLook/PreviewViewController.swift`

**Step 1: Add the logger**

Create `QMarkShared/Performance/QMarkPerformanceLog.swift`:

```swift
import Foundation
import OSLog

enum QMarkPerformanceLog {
    static let logger = Logger(subsystem: "com.qmark.app", category: "performance")
    static let pointsOfInterest = OSLog(subsystem: "com.qmark.app", category: .pointsOfInterest)
}
```

**Step 2: Instrument editor creation**

In `QMark/Editor/EditorView.swift`, import `OSLog` and add a signpost around `makeNSView`:

```swift
let signpostID = OSSignpostID(log: QMarkPerformanceLog.pointsOfInterest)
os_signpost(.begin, log: QMarkPerformanceLog.pointsOfInterest, name: "EditorView.makeNSView", signpostID: signpostID)
defer {
    os_signpost(.end, log: QMarkPerformanceLog.pointsOfInterest, name: "EditorView.makeNSView", signpostID: signpostID)
}
```

**Step 3: Instrument Quick Look preparation**

In `QMarkQuickLook/PreviewViewController.swift`, log prepare start and file decode completion:

```swift
QMarkPerformanceLog.logger.info("Quick Look prepare started for \(url.lastPathComponent, privacy: .public)")
QMarkPerformanceLog.logger.info("Quick Look decoded \(markdownText.utf8.count, privacy: .public) bytes")
```

**Step 4: Verify**

Run:

```bash
make build
```

Expected: build succeeds.

**Step 5: Commit**

```bash
git add QMarkShared/Performance/QMarkPerformanceLog.swift QMark/Editor/EditorView.swift QMarkQuickLook/PreviewViewController.swift
git commit -m "chore: add preview performance logging"
```

## Task 3: Make The Main Window Preview-First

**Files:**
- Modify: `QMark/ContentView.swift`

**Step 1: Change the default editor visibility**

Change:

```swift
@State private var isEditorVisible: Bool = true
```

to:

```swift
@State private var isEditorVisible: Bool = false
```

**Step 2: Keep preview text initialized from the document**

Keep the existing `onAppear` assignment:

```swift
markdownText = document.text
```

Do not move `EditorView` outside the `if isEditorVisible` branch.

**Step 3: Verify lazy editor behavior**

Run:

```bash
make build
open build/Build/Products/Debug/QMark.app tmp/perf/markdown-1mb.md
```

Expected:

- The file opens in preview-only mode.
- The editor pane is hidden.
- The editor toolbar button reveals editing.
- `EditorView.makeNSView` logging appears only after editing is enabled.

**Step 4: Commit**

```bash
git add QMark/ContentView.swift
git commit -m "perf: open documents in preview mode"
```

## Task 4: Add A Preview Render Model

**Files:**
- Create: `QMark/Preview/MarkdownPreviewModel.swift`
- Modify: `QMark/ContentView.swift`
- Modify: `QMark/Preview/PreviewView.swift`

**Step 1: Create the model**

Create `QMark/Preview/MarkdownPreviewModel.swift`:

```swift
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
```

**Step 2: Use the model from `ContentView`**

Add:

```swift
@StateObject private var previewModel = MarkdownPreviewModel()
```

Change editor text updates from:

```swift
markdownText = text
```

to:

```swift
markdownText = text
previewModel.scheduleUpdate(text)
```

Change preview input from `markdownText` to `previewModel.markdown`.

In `onAppear`, after `markdownText = document.text`, add:

```swift
previewModel.load(document.text)
```

**Step 3: Verify debounced preview updates**

Run:

```bash
make build
open build/Build/Products/Debug/QMark.app tmp/perf/markdown-1mb.md
```

Expected:

- Initial preview renders.
- Editing updates the document immediately.
- Preview updates after a short delay.

**Step 4: Commit**

```bash
git add QMark/Preview/MarkdownPreviewModel.swift QMark/ContentView.swift QMark/Preview/PreviewView.swift
git commit -m "perf: debounce markdown preview updates"
```

## Task 5: Add Streaming Preview Rendering

**Files:**
- Modify: `QMark/Preview/MarkdownPreviewModel.swift`
- Modify: `QMarkShared/Preview/QMarkMarkdownPreview.swift`
- Modify: `QMark/Preview/PreviewView.swift`
- Modify: `QMarkQuickLook/PreviewViewController.swift`

**Step 1: Add a shared preview source type**

In `QMarkShared/Preview/QMarkMarkdownPreview.swift`, add:

```swift
enum QMarkMarkdownPreviewSource {
    case text(String)
    case streaming(StreamingMarkdownSource)
}
```

Add an initializer that accepts `QMarkMarkdownPreviewSource`.

Render `.streaming` through:

```swift
StreamingMarkdownReader(source) { parseResult in
    MarkdownView(parseResult)
}
```

Keep the existing text initializer for small direct renders and compatibility.

**Step 2: Extend the model with streaming source state**

Update `MarkdownPreviewModel` to publish a unified preview source:

```swift
@Published private(set) var previewSource: QMarkMarkdownPreviewSource = .text("")
private var streamingTask: Task<Void, Never>?
```

Update `load(_:)`:

```swift
func load(_ text: String) {
    pendingTask?.cancel()
    streamText(text)
}
```

Update the debounced render path so it streams after the delay:

```swift
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
```

**Step 3: Use streaming for initial app preview**

Keep this existing call from Task 4:

```swift
previewModel.load(document.text)
```

Pass `previewModel.previewSource` to `PreviewView`.

**Step 4: Use streaming in Quick Look**

In `QMarkQuickLook/PreviewViewController.swift`, create a `StreamingMarkdownSource`, install a preview view that uses it, then append chunks from a task.

Keep `handler(nil)` after the hosting view is installed and the streaming task starts.

**Step 5: Verify**

Run:

```bash
make build
open build/Build/Products/Debug/QMark.app tmp/perf/markdown-5mb.md
qlmanage -p tmp/perf/markdown-5mb.md
```

Expected:

- The app opens preview-only without creating the editor.
- Quick Look opens without hanging.
- The preview progressively completes full Markdown rendering.
- No plain-text fallback is used.

**Step 6: Commit**

```bash
git add QMark/Preview/MarkdownPreviewModel.swift QMarkShared/Preview/QMarkMarkdownPreview.swift QMark/Preview/PreviewView.swift QMarkQuickLook/PreviewViewController.swift
git commit -m "perf: stream markdown preview rendering"
```

## Task 6: Add Native Preview Scroll Control

**Files:**
- Modify: `QMarkShared/Preview/QMarkMarkdownPreview.swift`
- Modify: `QMark/Preview/PreviewView.swift`

**Step 1: Keep the proven SwiftUI preview scroll path**

Do not wrap MarkdownView content in an AppKit `NSScrollView`. The preview should remain:

```swift
ScrollView {
    renderedContent
}
```

This preserves the MarkdownView rendering lifecycle used by the working preview and Quick Look paths.

**Step 2: Add preview scroll state**

In `QMarkMarkdownPreview`, add:

```swift
let scrollPercentage: CGFloat
let onScrollChange: (CGFloat) -> Void
let scrollSyncEnabled: Bool

@State private var scrollPosition = ScrollPosition()
@State private var scrollState = QMarkMarkdownScrollState()
```

Use `onScrollGeometryChange` to convert `ScrollGeometry` into a clamped percentage, but store high-frequency metrics in a non-publishing state object so scrolling does not continuously invalidate the Markdown render tree. Use `ScrollPosition.scrollTo(y:)` to apply external percentage changes.

**Step 3: Prevent local feedback loops**

When applying an external scroll, suppress preview-originated scroll callbacks briefly and skip changes below a small point tolerance. This keeps the preview from reporting its own programmatic scroll back to `ContentView` as a new user action.

**Step 4: Pass preview scroll values through `PreviewView`**

Pass `scrollPercentage` and `onScrollChange` from `PreviewView` into `QMarkMarkdownPreview`.

**Step 5: Verify**

Run:

```bash
make build
open build/Build/Products/Debug/QMark.app tmp/perf/markdown-1mb.md
```

Expected:

- Preview scrolls normally.
- Markdown content is visible; no blank preview is introduced.
- Text selection still works.
- Links still open through the existing `openURL` environment handler.
- Quick Look keeps using the same `QMarkMarkdownPreview` defaults without needing scroll callbacks.

**Step 6: Commit**

```bash
git add QMarkShared/Preview/QMarkMarkdownPreview.swift QMark/Preview/PreviewView.swift docs/plans/2026-06-30-preview-performance-design.md docs/plans/2026-06-30-preview-performance-implementation.md
git commit -m "feat: add native markdown preview scroll control"
```

## Task 7: Add Bidirectional Scroll Sync

**Files:**
- Modify: `EditorRenderer/editor.js`
- Modify: `QMark/Editor/EditorView.swift`
- Modify: `QMark/Preview/PreviewView.swift`
- Modify: `QMark/ContentView.swift`
- Modify: `QMarkShared/Preview/QMarkMarkdownPreview.swift`

**Step 1: Add editor scroll setter**

In `EditorRenderer/editor.js`, add `window.setScrollPercentage(percentage)`.

Requirements:

- clamp the percentage to `0...1`;
- wait for CodeMirror layout with `requestAnimationFrame` when scroll height is not ready;
- suppress programmatic scroll notifications while applying the scroll.

**Step 2: Add Swift API for editor scrolling**

In `EditorView.Coordinator`, add `syncScrollIfNeeded(_:)` that stores pending scroll values until `editorReady`, skips tiny percentage changes, and calls:

```swift
webView.callAsyncJavaScript(
    "setScrollPercentage(percentage)",
    arguments: ["percentage": Double(clampedPercentage)],
    in: nil,
    in: .page,
    completionHandler: nil
)
```

**Step 3: Wire shared scroll state and source guard**

In `ContentView`, keep a single shared `scrollPercentage` plus a short-lived `activeScrollSource`.

- Editor scroll events update the shared value.
- Preview scroll events update the shared value.
- `EditorView` consumes the shared value through `scrollPercentage`.
- `PreviewView` consumes and reports the shared value through `scrollPercentage` and `onScrollChange`.

Ignore cross-source scroll reports while another source is active. The renderers also keep local safeguards: CodeMirror suppresses programmatic scroll notifications, and the SwiftUI preview suppresses callbacks while applying external scroll. Both sides throttle high-frequency scroll reports so scrolling does not continuously invalidate the full Markdown preview tree.

**Step 4: Verify**

Run:

```bash
make build
open build/Build/Products/Debug/QMark.app tmp/perf/markdown-1mb.md
```

Expected:

- Scrolling the editor moves the preview.
- Scrolling the preview moves the editor.
- Opening the editor after scrolling the preview applies the current preview position after CodeMirror layout is ready.
- The panes do not jitter or fight each other.
- Selection in the editor remains responsive while scrolling.

**Step 5: Commit**

```bash
git add EditorRenderer/editor.js QMark/Editor/EditorView.swift QMark/Preview/PreviewView.swift QMark/ContentView.swift QMarkShared/Preview/QMarkMarkdownPreview.swift
git commit -m "feat: sync editor and preview scrolling"
```

## Task 8: Final Verification And Documentation

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`

**Step 1: Update docs**

Update `README.md` to describe:

- preview-first opening;
- editor lazy loading;
- streaming Markdown preview rendering;
- bidirectional scroll sync.

Update `CHANGELOG.md` under `Unreleased`:

```markdown
### Changed
- Open Markdown documents in preview mode by default and lazy-load the editor.
- Stream Markdown preview rendering for large files while preserving full Markdown output.

### Fixed
- Restored bidirectional editor and preview scroll synchronization.
```

**Step 2: Run full local verification**

Run:

```bash
make build
codesign --verify --deep --strict --verbose=2 build/Build/Products/Debug/QMark.app
scripts/generate-markdown-fixtures.sh
open build/Build/Products/Debug/QMark.app tmp/perf/markdown-500kb.md
open build/Build/Products/Debug/QMark.app tmp/perf/markdown-5mb.md
qlmanage -p tmp/perf/markdown-5mb.md
qlmanage -p tmp/perf/markdown-10mb.md
```

Expected:

- Build succeeds.
- Code signing verification succeeds.
- 500 KB and 5 MB files open preview-first.
- Editor is hidden until the toolbar button is clicked.
- Quick Look remains responsive for 5 MB.
- 10 MB Quick Look does not hang, although complete rendering may take several seconds.
- No plain-text fallback is used.

**Step 3: Commit**

```bash
git add README.md CHANGELOG.md
git commit -m "docs: document preview performance improvements"
```

## Rollback Plan

If streaming rendering causes regressions:

1. Keep preview-first editor lazy loading.
2. Revert only the streaming preview changes.
3. Keep debounced preview updates.
4. Re-run the 500 KB, 1 MB, 5 MB, and 10 MB fixture checks.

## Notes For Implementation

- Do not replace CodeMirror in this phase.
- Do not add Mermaid support in this phase.
- Do not add a plain-text fallback for large Markdown files.
- Keep user-facing behavior native macOS and minimal.
- Prefer small commits after each verified task.
