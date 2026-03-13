# QMark Editor V2 — CodeMirror 6 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken NSTextView editor with WKWebView + CodeMirror 6 while keeping all other modules unchanged.

**Architecture:** Left panel becomes a WKWebView running CodeMirror 6 (Markdown mode + syntax highlighting + line numbers + search + history). Right panel (WKWebView + markdown-it preview) stays unchanged. Swift ↔ JS bridge via WKScriptMessageHandler handles content sync.

**Tech Stack:** CodeMirror 6 (esbuild-bundled), WKWebView, SwiftUI NSViewRepresentable, ReferenceFileDocument

**Spec:** `docs/superpowers/specs/2026-03-13-qmark-editor-v2-design.md`

---

## Chunk 1: CodeMirror Bundle & EditorRenderer Resources

### Task 1: Create CodeMirror build script and generate bundle

**Files:**
- Create: `scripts/build-editor.sh`
- Create: `EditorRenderer/libs/codemirror.min.js` (generated)

**Prerequisite:** Node.js and npm must be installed.

- [ ] **Step 1: Create the build script**

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUT_DIR="$PROJECT_DIR/EditorRenderer/libs"
TEMP_DIR=$(mktemp -d)

trap "rm -rf $TEMP_DIR" EXIT

echo "==> Setting up temporary build environment..."
cd "$TEMP_DIR"

cat > package.json << 'PKGJSON'
{
  "name": "qmark-editor-bundle",
  "private": true,
  "type": "module"
}
PKGJSON

npm install codemirror @codemirror/lang-markdown @codemirror/language-data esbuild

echo "==> Creating entry point..."
cat > entry.js << 'ENTRY'
// Re-export everything CodeMirror needs as globals for non-module usage
export {EditorView, basicSetup} from "codemirror"
export {EditorState} from "@codemirror/state"
export {keymap} from "@codemirror/view"
export {markdown, markdownLanguage} from "@codemirror/lang-markdown"
export {languages} from "@codemirror/language-data"
ENTRY

echo "==> Bundling with esbuild..."
npx esbuild entry.js \
  --bundle \
  --minify \
  --format=esm \
  --outfile=codemirror.min.js

echo "==> Copying to $OUT_DIR..."
mkdir -p "$OUT_DIR"
cp codemirror.min.js "$OUT_DIR/"

echo "==> Done! Bundle at $OUT_DIR/codemirror.min.js ($(wc -c < codemirror.min.js | tr -d ' ') bytes)"
```

Write this to `scripts/build-editor.sh`.

- [ ] **Step 2: Make it executable and run**

```bash
chmod +x scripts/build-editor.sh
mkdir -p EditorRenderer/libs
bash scripts/build-editor.sh
```

Expected: `EditorRenderer/libs/codemirror.min.js` is created, ~150-250KB.

- [ ] **Step 3: Verify the bundle exists and has reasonable size**

```bash
ls -lh EditorRenderer/libs/codemirror.min.js
```

Expected: File exists, 150-300KB.

- [ ] **Step 4: Commit**

```bash
git add scripts/build-editor.sh EditorRenderer/libs/codemirror.min.js
git commit -m "feat: add CodeMirror 6 build script and bundle"
```

---

### Task 2: Create editor.html

**Files:**
- Create: `EditorRenderer/editor.html`

- [ ] **Step 1: Create the HTML template**

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="editor.css">
    <style>
        html, body {
            margin: 0;
            padding: 0;
            height: 100%;
            overflow: hidden;
        }
        #editor {
            height: 100%;
        }
    </style>
</head>
<body>
    <div id="editor"></div>
    <script type="module" src="editor.js"></script>
</body>
</html>
```

Write to `EditorRenderer/editor.html`.

- [ ] **Step 2: Commit**

```bash
git add EditorRenderer/editor.html
git commit -m "feat: add editor HTML template"
```

---

### Task 3: Create editor.js (CodeMirror init + Swift bridge)

**Files:**
- Create: `EditorRenderer/editor.js`

This is the core file. It initializes CodeMirror 6 with all extensions, sets up the Swift ↔ JS bridge, and handles keyboard shortcuts.

- [ ] **Step 1: Create editor.js**

```javascript
import {EditorView, basicSetup} from "./libs/codemirror.min.js";
import {EditorState} from "./libs/codemirror.min.js";
import {keymap} from "./libs/codemirror.min.js";
import {markdown, markdownLanguage} from "./libs/codemirror.min.js";
import {languages} from "./libs/codemirror.min.js";

// ── Debounce helper ──
let debounceTimer = null;
function debounce(fn, ms) {
    return (...args) => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => fn(...args), ms);
    };
}

// ── Swift bridge helpers ──
function postMessage(name, body) {
    try {
        window.webkit.messageHandlers[name].postMessage(body);
    } catch (e) {
        // Not in WKWebView context (e.g., testing in browser)
        console.log(`[bridge] ${name}:`, body);
    }
}

const notifyContentChanged = debounce((text) => {
    postMessage("contentChanged", text);
}, 300);

// ── Markdown keyboard shortcuts (⌘B, ⌘I, ⌘K) ──
function wrapSelection(view, wrapper) {
    const {from, to} = view.state.selection.main;
    const selected = view.state.sliceDoc(from, to);
    const replacement = wrapper + selected + wrapper;
    view.dispatch({
        changes: {from, to, insert: replacement},
        selection: {anchor: from + wrapper.length, head: to + wrapper.length}
    });
    return true;
}

function insertLink(view) {
    const {from, to} = view.state.selection.main;
    const selected = view.state.sliceDoc(from, to);
    const replacement = `[${selected}](url)`;
    view.dispatch({
        changes: {from, to, insert: replacement},
        selection: {anchor: from + selected.length + 3, head: from + selected.length + 6}
    });
    return true;
}

const markdownKeymap = keymap.of([
    {key: "Mod-b", run: (view) => wrapSelection(view, "**")},
    {key: "Mod-i", run: (view) => wrapSelection(view, "*")},
    {key: "Mod-k", run: (view) => insertLink(view)},
]);

// ── Scroll sync ──
function setupScrollSync(view) {
    const scrollDOM = view.scrollDOM;
    scrollDOM.addEventListener("scroll", () => {
        const scrollTop = scrollDOM.scrollTop;
        const scrollHeight = scrollDOM.scrollHeight - scrollDOM.clientHeight;
        const percentage = scrollHeight > 0 ? scrollTop / scrollHeight : 0;
        postMessage("scrollChanged", percentage);
    });
}

// ── Initialize CodeMirror ──
const editor = new EditorView({
    parent: document.getElementById("editor"),
    state: EditorState.create({
        doc: "",
        extensions: [
            basicSetup,
            markdown({base: markdownLanguage, codeLanguages: languages}),
            markdownKeymap,
            EditorView.updateListener.of((update) => {
                if (update.docChanged) {
                    notifyContentChanged(update.state.doc.toString());
                }
            }),
            EditorView.theme({
                "&": {height: "100%"},
                ".cm-scroller": {overflow: "auto"},
            }),
        ],
    }),
});

setupScrollSync(editor);

// ── Swift → JS API ──
// These functions are called via WKWebView.callAsyncJavaScript()

window.setContent = function(text) {
    editor.dispatch({
        changes: {from: 0, to: editor.state.doc.length, insert: text}
    });
};

window.getContent = function() {
    return editor.state.doc.toString();
};

// ── Notify Swift that editor is ready ──
postMessage("editorReady", true);
```

Write to `EditorRenderer/editor.js`.

- [ ] **Step 2: Commit**

```bash
git add EditorRenderer/editor.js
git commit -m "feat: add CodeMirror editor initialization and Swift bridge"
```

---

### Task 4: Create editor.css (theme + typography)

**Files:**
- Create: `EditorRenderer/editor.css`

- [ ] **Step 1: Create editor.css**

```css
/* ── Base typography ── */
.cm-editor .cm-content {
    font-family: ui-monospace, "SF Mono", SFMono-Regular, Menlo, monospace;
    font-size: 14px;
    line-height: 1.5;
    padding: 16px;
}

.cm-editor .cm-gutters {
    font-family: ui-monospace, "SF Mono", SFMono-Regular, Menlo, monospace;
    font-size: 11px;
}

/* ── Light theme (default) ── */
.cm-editor {
    background-color: #ffffff;
    color: #24292f;
}

.cm-editor .cm-gutters {
    background-color: #ffffff;
    color: rgba(36, 41, 47, 0.3);
    border-right: 1px solid #d0d7de;
}

.cm-editor .cm-activeLineGutter {
    background-color: #f6f8fa;
}

.cm-editor .cm-activeLine {
    background-color: #f6f8fa;
}

.cm-editor .cm-cursor {
    border-left-color: #24292f;
}

.cm-editor .cm-selectionBackground,
.cm-editor.cm-focused .cm-selectionBackground {
    background-color: #b6d7ff;
}

/* ── Dark theme ── */
@media (prefers-color-scheme: dark) {
    .cm-editor {
        background-color: #0d1117;
        color: #c9d1d9;
    }

    .cm-editor .cm-gutters {
        background-color: #0d1117;
        color: rgba(201, 209, 217, 0.3);
        border-right: 1px solid #30363d;
    }

    .cm-editor .cm-activeLineGutter {
        background-color: #161b22;
    }

    .cm-editor .cm-activeLine {
        background-color: #161b22;
    }

    .cm-editor .cm-cursor {
        border-left-color: #c9d1d9;
    }

    .cm-editor .cm-selectionBackground,
    .cm-editor.cm-focused .cm-selectionBackground {
        background-color: #264f78;
    }
}
```

Write to `EditorRenderer/editor.css`.

- [ ] **Step 2: Commit**

```bash
git add EditorRenderer/editor.css
git commit -m "feat: add editor theme with light/dark mode support"
```

---

## Chunk 2: Swift-Side Changes (Atomic)

> **Note:** Tasks 5-8 modify interdependent files. They must ALL be completed before the project will compile. Do not attempt to build between individual tasks in this chunk.

### Task 5: Rewrite MarkdownDocument

**Files:**
- Rewrite: `QMark/MarkdownDocument.swift`

Change from NSTextStorage to @Published String. Keep UTType definitions unchanged.

- [ ] **Step 1: Rewrite MarkdownDocument.swift**

```swift
import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Custom UTType Definitions

extension UTType {
    static let qmarkMarkdown: UTType = UTType("net.daringfireball.markdown")
        ?? UTType(filenameExtension: "md", conformingTo: .plainText)
        ?? .plainText
    static let qmarkMdx = UTType("com.qmark.mdx") ?? UTType(filenameExtension: "mdx", conformingTo: .plainText) ?? .plainText
    static let qmarkRmd = UTType("com.qmark.rmd") ?? UTType(filenameExtension: "rmd", conformingTo: .plainText) ?? .plainText
    static let qmarkMdown = UTType("com.qmark.mdown") ?? UTType(filenameExtension: "mdown", conformingTo: .plainText) ?? .plainText
    static let qmarkMkd = UTType("com.qmark.mkd") ?? UTType(filenameExtension: "mkd", conformingTo: .plainText) ?? .plainText
}

// MARK: - MarkdownDocument

final class MarkdownDocument: ReferenceFileDocument, @unchecked Sendable {

    static var readableContentTypes: [UTType] {
        [.qmarkMarkdown, .qmarkMdx, .qmarkRmd, .qmarkMdown, .qmarkMkd, .plainText]
    }

    static var writableContentTypes: [UTType] {
        [.qmarkMarkdown]
    }

    @Published var text: String

    /// Create empty document
    init() {
        self.text = ""
    }

    /// Read from file
    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    /// Save snapshot
    func snapshot(contentType: UTType) throws -> String {
        text
    }

    /// Write to file
    func fileWrapper(snapshot: String, configuration: WriteConfiguration) throws -> FileWrapper {
        let data = snapshot.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}
```

Write to `QMark/MarkdownDocument.swift`.

---

### Task 6: Delete old editor files and rewrite EditorView

**Files:**
- Delete: `QMark/Editor/MarkdownHighlighter.swift`
- Delete: `QMark/Editor/EditorTheme.swift`
- Delete: `QMarkTests/EditorViewTests.swift`
- Rewrite: `QMark/Editor/EditorView.swift`

- [ ] **Step 1: Delete old files**

```bash
rm QMark/Editor/MarkdownHighlighter.swift
rm QMark/Editor/EditorTheme.swift
rm QMarkTests/EditorViewTests.swift
```

- [ ] **Step 2: Rewrite EditorView.swift**

This replaces the entire NSTextView implementation with a WKWebView that loads CodeMirror.

```swift
import SwiftUI
import WebKit

struct EditorView: NSViewRepresentable {
    @ObservedObject var document: MarkdownDocument
    var onTextChange: ((String) -> Void)?
    var onScrollChange: ((CGFloat) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // 注册 JS → Swift 消息处理
        let contentController = config.userContentController
        contentController.add(context.coordinator, name: "editorReady")
        contentController.add(context.coordinator, name: "contentChanged")
        contentController.add(context.coordinator, name: "scrollChanged")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView

        // 加载编辑器 HTML
        if let editorURL = Bundle.main.url(
            forResource: "editor",
            withExtension: "html",
            subdirectory: "EditorRenderer"
        ) {
            webView.loadFileURL(
                editorURL,
                allowingReadAccessTo: editorURL.deletingLastPathComponent()
            )
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // 处理外部修改（如文件 revert）
        context.coordinator.syncIfNeeded(document.text)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler {
        let parent: EditorView
        weak var webView: WKWebView?
        private var isEditorReady = false
        private var pendingContent: String?
        private var lastSentContent: String?
        private var isSyncingFromJS = false

        init(_ parent: EditorView) {
            self.parent = parent
            super.init()
        }

        // MARK: - Content Sync

        /// 当编辑器就绪后，发送初始内容
        private func sendContent(_ text: String) {
            guard isEditorReady, let webView = webView else {
                pendingContent = text
                return
            }
            lastSentContent = text
            webView.callAsyncJavaScript(
                "setContent(text)",
                arguments: ["text": text],
                in: nil,
                in: .page,
                completionHandler: nil
            )
        }

        /// 处理外部修改（如文件 revert）— 从 updateNSView 调用
        func syncIfNeeded(_ text: String) {
            guard !isSyncingFromJS else { return }
            guard text != lastSentContent else { return }
            sendContent(text)
        }

        // MARK: - WKScriptMessageHandler

        nonisolated func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            Task { @MainActor in
                handleMessage(message)
            }
        }

        private func handleMessage(_ message: WKScriptMessage) {
            switch message.name {
            case "editorReady":
                isEditorReady = true
                // 发送初始内容或缓存的内容
                let content = pendingContent ?? parent.document.text
                pendingContent = nil
                sendContent(content)

            case "contentChanged":
                guard let text = message.body as? String else { return }
                isSyncingFromJS = true
                lastSentContent = text
                parent.document.text = text
                parent.onTextChange?(text)
                isSyncingFromJS = false

            case "scrollChanged":
                if let percentage = message.body as? Double {
                    parent.onScrollChange?(CGFloat(percentage))
                }

            default:
                break
            }
        }
    }
}
```

Write to `QMark/Editor/EditorView.swift`.

---

### Task 7: Update ContentView

**Files:**
- Modify: `QMark/ContentView.swift`

Change `document.textStorage.string` to `document.text` in `onAppear`.

- [ ] **Step 1: Update ContentView.swift**

Change:
```swift
markdownText = document.textStorage.string
```
to:
```swift
markdownText = document.text
```

---

### Task 8: Commit all Swift-side changes

All four tasks (5-7) modify interdependent files. Commit them together.

- [ ] **Step 1: Commit**

```bash
git add -A QMark/MarkdownDocument.swift QMark/Editor/ QMark/ContentView.swift QMarkTests/
git commit -m "feat: replace NSTextView editor with WKWebView + CodeMirror 6

- Rewrite MarkdownDocument (NSTextStorage → @Published String)
- Rewrite EditorView (NSTextView → WKWebView + CodeMirror)
- Update ContentView data flow
- Delete MarkdownHighlighter, EditorTheme, old tests"
```

---

## Chunk 3: Project Config, Build & Verify

### Task 9: Update project.yml

**Files:**
- Modify: `project.yml`

Add `EditorRenderer` as a resource folder for the QMark target. Also remove `QMarkTests` target (its only test file was deleted, and we can re-add it later when new tests are written).

- [ ] **Step 1: Add EditorRenderer source to QMark target**

In `project.yml`, under `targets.QMark.sources`, add a new entry after the SharedRenderer entry:

```yaml
      - path: EditorRenderer
        type: folder
        buildPhase: resources
```

So the sources section becomes:
```yaml
    sources:
      - path: QMark
        type: group
      - path: SharedRenderer
        type: folder
        buildPhase: resources
      - path: EditorRenderer
        type: folder
        buildPhase: resources
```

- [ ] **Step 2: Remove QMarkTests target (empty after test deletion)**

Delete the entire `QMarkTests` target block from `project.yml` (lines 146-157), and remove the empty `QMarkTests` directory:

```bash
rm -rf QMarkTests
```

- [ ] **Step 3: Commit**

```bash
git add project.yml
git add -A QMarkTests
git commit -m "chore: add EditorRenderer resources, remove empty QMarkTests"
```

---

### Task 10: Update Makefile

**Files:**
- Modify: `Makefile`

Add `editor-libs` target.

- [ ] **Step 1: Update Makefile**

Replace the entire Makefile with:

```makefile
.PHONY: generate build run clean editor-libs

editor-libs:
	bash scripts/build-editor.sh

generate:
	xcodegen generate

build: generate
	xcodebuild -project QMark.xcodeproj -scheme QMark -configuration Debug -derivedDataPath build build

run: build
	open build/Build/Products/Debug/QMark.app

clean:
	rm -rf build DerivedData
	xcodebuild -project QMark.xcodeproj -scheme QMark clean 2>/dev/null || true
```

- [ ] **Step 2: Commit**

```bash
git add Makefile
git commit -m "chore: add editor-libs target to Makefile"
```

---

### Task 11: Build and verify

- [ ] **Step 1: Clean build**

```bash
pkill -f QMark.app 2>/dev/null || true
rm -rf build
make build
```

Expected: `** BUILD SUCCEEDED **`

If build fails, check error messages and fix. Common issues:
- Missing `import AppKit` in MarkdownDocument.swift (may not need it anymore — remove if unused)
- Swift 6 concurrency warnings in WKScriptMessageHandler (already handled with `nonisolated` + `Task { @MainActor }`)

- [ ] **Step 2: Launch and test**

```bash
make run
```

Test the following:
1. **New document**: File → New — editor should show empty CodeMirror with line numbers
2. **Open .md file**: File → Open — editor should show file content with Markdown syntax highlighting
3. **Edit**: Type text in editor — right preview should update after ~300ms
4. **Shortcuts**: Select text, press ⌘B — should wrap with `**`
5. **Find**: Press ⌘F — CodeMirror search panel should appear
6. **Dark mode**: Toggle system appearance — editor should switch theme
7. **Scroll sync**: Scroll in editor — preview should follow

- [ ] **Step 3: Fix any issues found during testing**

Address issues as needed.

- [ ] **Step 4: Final commit if any fixes were made**

```bash
git add -A
git commit -m "fix: address issues found during manual testing"
```
