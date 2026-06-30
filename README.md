# QMark

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-black.svg)](#requirements)
[![Swift](https://img.shields.io/badge/Swift%20tools-6.2%2B-F05138.svg?logo=swift&logoColor=white)](#requirements)
[![XcodeGen](https://img.shields.io/badge/XcodeGen-required-0A84FF.svg)](#build-from-source)

QMark is a native macOS Markdown reader and editor with a preview-first SwiftUI MarkdownView renderer, an on-demand CodeMirror editing surface, and a bundled Quick Look extension for Finder previews.

[English](README.md) | [Simplified Chinese](README.zh-CN.md) | [Changelog](CHANGELOG.md)

## Current Direction

QMark renders Markdown through a native SwiftUI preview powered by [MarkdownView](https://github.com/LiYanan2004/MarkdownView). The main app preview and the Quick Look extension share the same preview component so their Markdown behavior stays aligned.

The editor remains web-based through WKWebView and CodeMirror 6 because that path gives QMark a strong text editing surface, keyboard behavior, and Markdown authoring workflow. The editor is created only when editing is enabled; normal document opening starts in preview mode.

## Features

- Preview-first document opening with the editor hidden by default.
- Lazy-loaded CodeMirror 6 editor with Markdown syntax highlighting.
- Shared MarkdownView preview in the main app and Quick Look extension.
- Streaming MarkdownView updates for app previews and Quick Look previews.
- Percentage-based bidirectional scroll synchronization between the editor and preview.
- Finder Quick Look support for Markdown files.
- macOS-native document handling through `ReferenceFileDocument`.
- Light, dark, and system appearance modes.
- Keyboard shortcuts for common Markdown editing actions.
- Resizable editor and preview panes when editing is enabled.
- Markdown support for headings, lists, tables, task lists, code blocks, math, links, and common GitHub-flavored Markdown content.
- Supported file extensions: `.md`, `.markdown`, `.mdx`, `.rmd`, `.mdown`, and `.mkd`.

## Preview Behavior

The current preview implementation lives in `QMarkShared/Preview/QMarkMarkdownPreview.swift`.

```text
QMark/Preview/PreviewView.swift
        │
        ▼
QMarkShared/Preview/QMarkMarkdownPreview.swift
        ▲
        │
QMarkQuickLook/PreviewViewController.swift
```

This keeps the app preview and Finder Quick Look preview on the same Markdown rendering path. The main app streams Markdown into the preview model and debounces editor-originated preview updates so typing and scrolling stay responsive on larger documents.

The main app enables percentage-based scroll synchronization between the editor and preview. Quick Look uses the same Markdown renderer with scroll synchronization disabled, which keeps Finder previews isolated from app-only editing state.

MarkdownView is pinned in `project.yml` to:

```text
82cf1bba9d2c5fdf52d895506e4142fcbbcfe157
```

Mermaid rendering is intentionally deferred in this migration phase. Mermaid fenced blocks are rendered as code blocks until a native or isolated diagram rendering strategy is added later.

## Quick Look

QMark includes a Quick Look preview extension at `QMarkQuickLook/`. After installing or replacing a local build, refresh Quick Look registration:

```bash
qlmanage -r
qlmanage -r cache
```

If Finder still shows stale behavior, relaunch Finder:

```bash
killall Finder
```

For local debugging, verify the extension is registered from the expected app bundle:

```bash
pluginkit -m -A -D -vv | grep -A 8 -B 2 "com.qmark.app.quicklook"
```

## Requirements

- macOS 15.0+
- Xcode 26.0+ with Swift tools 6.2+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Apple Development signing identity for local app and extension builds
- Node.js only when rebuilding the CodeMirror bundle

## Build From Source

Install XcodeGen if needed:

```bash
brew install xcodegen
```

Create local signing configuration:

```bash
cp Local.xcconfig.example Local.xcconfig
```

Edit `Local.xcconfig` and set your Apple Developer Team ID.

Generate the Xcode project and build:

```bash
make build
```

Launch the Debug build:

```bash
make run
```

Clean generated build output:

```bash
make clean
```

Rebuild the CodeMirror bundle:

```bash
make editor-libs
```

Re-download legacy web preview libraries kept for rollback:

```bash
bash scripts/download-libs.sh
```

## Verification

There is no dedicated XCTest target yet. Use the Debug build plus manual smoke testing.

Generate local performance fixtures:

```bash
scripts/generate-markdown-fixtures.sh
```

Use the generated files in `tmp/perf/` for app and Quick Look smoke testing.

Recommended local verification:

```bash
make build
codesign --verify --deep --strict --verbose=2 build/Build/Products/Debug/QMark.app
```

Manual smoke test checklist:

- Open a Markdown file in QMark.
- Confirm the file opens in preview mode without showing the editor pane.
- Use the toolbar sidebar button to show the editor.
- Edit Markdown in the CodeMirror editor.
- Confirm the native preview updates.
- Scroll the editor and preview panes and confirm both directions stay synchronized.
- Toggle light, dark, and system appearance modes.
- Preview the same Markdown file in Finder with Quick Look.
- Confirm Mermaid fenced blocks remain visible as code blocks.

## Project Layout

```text
QMark/
├── QMarkApp.swift
├── ContentView.swift
├── MarkdownDocument.swift
├── CleanWebView.swift
├── Editor/
│   └── EditorView.swift
└── Preview/
    ├── PreviewView.swift
    └── PreviewBridge.swift

QMarkShared/
└── Preview/
    └── QMarkMarkdownPreview.swift

QMarkQuickLook/
├── PreviewViewController.swift
├── Info.plist
└── QMarkQuickLook.entitlements

EditorRenderer/
├── editor.html
├── editor.js
├── editor.css
└── libs/
    └── codemirror.min.js

SharedRenderer/
├── template.html
├── renderer.js
├── style.css
└── libs/

scripts/
docs/
```

## Architecture Notes

| Area | Implementation |
|------|----------------|
| App UI | SwiftUI |
| Document model | `ReferenceFileDocument` |
| Editor | WKWebView + CodeMirror 6 |
| Main preview | SwiftUI + MarkdownView |
| Quick Look preview | App extension + shared MarkdownView preview |
| Code highlighting | MarkdownView + Highlightr |
| Math | MarkdownView math rendering |
| Project generation | XcodeGen |
| Editor bundle | esbuild |

`SharedRenderer/` remains in the repository as a rollback path for the previous HTML preview implementation. New preview work should start from `QMarkShared/Preview/QMarkMarkdownPreview.swift`.

## Current Limitations

- Mermaid diagrams are not rendered yet.
- Scroll synchronization is percentage-based, not AST- or heading-based.
- The Chinese README is not maintained as the source of truth on this branch.
- The legacy HTML preview assets are kept only for rollback while the native preview migration is evaluated.

## License

QMark is licensed under the GNU General Public License v3.0 only. See [LICENSE](LICENSE) for details.
