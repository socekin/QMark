# QMark

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-black.svg)](#requirements)
[![Swift](https://img.shields.io/badge/Swift%20tools-6.2%2B-F05138.svg?logo=swift&logoColor=white)](#tech-stack)
[![XcodeGen](https://img.shields.io/badge/XcodeGen-required-0A84FF.svg)](#build)

A native macOS Markdown editor built with SwiftUI, MarkdownView, WKWebView, and CodeMirror 6.

[English](README.md) | [Simplified Chinese](README.zh-CN.md) | [Changelog](CHANGELOG.md)

## Features

- **Split View** — CodeMirror 6 editor on the left, native MarkdownView preview on the right
- **Syntax Highlighting** — CodeMirror editor highlighting and native highlighted code blocks in preview
- **Theme Switching** — Follow system, Light, or Dark mode with instant switching
- **Native Preview** — SwiftUI Markdown rendering shared by the main app and Quick Look extension
- **Keyboard Shortcuts** — `⌘B` bold, `⌘I` italic, `⌘K` insert link, `⌘F` find/replace
- **Resizable Split** — Drag the divider to adjust editor/preview ratio
- **Toggle Editor** — Collapse the editor for a distraction-free reading mode
- **QuickLook Extension** — Preview Markdown files in Finder with spacebar
- **Rich Content** — Code highlighting, math, task lists, tables, and common Markdown elements
- **Mermaid Deferred** — Mermaid fenced blocks are shown as code blocks in this migration phase
- **Multi-format** — `.md` / `.mdx` / `.rmd` / `.mdown` / `.mkd`

## Requirements

- macOS 15.0+
- Xcode 26.0+ with Swift tools 6.2+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Node.js (only needed when rebuilding the CodeMirror bundle)

## Build

```bash
# Install XcodeGen (if not already installed)
brew install xcodegen

# Generate Xcode project and build
make build

# Build and launch
make run

# Clean build artifacts
make clean

# Rebuild CodeMirror bundle (requires Node.js)
make editor-libs

# Re-download legacy web preview libraries kept for rollback
bash scripts/download-libs.sh
```

> **Note:** Before building, copy `Local.xcconfig.example` to `Local.xcconfig` and set your Apple Developer Team ID, or set `CODE_SIGN_STYLE` to `Manual` in `project.yml` and configure signing as needed.

## Verification

```bash
# Generate the project and verify the main app plus Quick Look extension build
make build

# Refresh Quick Look after installing a local build
qlmanage -r
qlmanage -r cache
```

There is no dedicated XCTest target at the moment. Use the Debug build plus manual smoke tests for the editor, native preview, and Finder Quick Look preview.

## Architecture

```
QMark/                       — Main app (SwiftUI)
├── QMarkApp.swift            — App entry, menu configuration
├── ContentView.swift         — Split view layout, toolbar, theme management
├── CleanWebView.swift        — WKWebView subclass used by the editor
├── MarkdownDocument.swift    — ReferenceFileDocument model
├── Editor/
│   └── EditorView.swift      — NSViewRepresentable wrapping CodeMirror 6
└── Preview/
    ├── PreviewView.swift     — SwiftUI wrapper around the shared native preview
    └── PreviewBridge.swift   — Legacy rollback bridge for the old web preview

QMarkShared/
└── Preview/
    └── QMarkMarkdownPreview.swift — Shared SwiftUI MarkdownView renderer

EditorRenderer/              — Editor web resources
├── editor.html              — HTML shell for CodeMirror
├── editor.js                — CodeMirror setup, themes, keyboard shortcuts, Swift bridge
├── editor.css               — Typography
└── libs/
    └── codemirror.min.js    — CodeMirror 6 bundle (built via esbuild)

SharedRenderer/              — Legacy preview web resources kept for rollback
├── template.html            — Legacy preview HTML template
├── renderer.js              — Legacy markdown-it initialization with plugins
├── style.css                — Legacy GitHub-style preview CSS
└── libs/                    — Legacy markdown-it, KaTeX, highlight.js, Mermaid, etc.

QMarkQuickLook/              — QuickLook preview extension
scripts/                     — Build scripts for JS dependencies
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Editor | WKWebView + [CodeMirror 6](https://codemirror.net/) |
| Preview | SwiftUI + [MarkdownView](https://github.com/LiYanan2004/MarkdownView) |
| Math | MarkdownView math rendering |
| Diagrams | Mermaid deferred; fenced blocks render as code |
| Code Highlighting | MarkdownView + Highlightr |
| Document Model | ReferenceFileDocument |
| UI Framework | SwiftUI |
| Project Generation | [XcodeGen](https://github.com/yonaskolb/XcodeGen) |
| JS Bundling | [esbuild](https://esbuild.github.io/) for the editor bundle |

## Preview Status

- MarkdownView is pinned in `project.yml` to commit `82cf1bba9d2c5fdf52d895506e4142fcbbcfe157`.
- The main app preview and Quick Look extension share `QMarkMarkdownPreview`, so Markdown rendering behavior stays aligned.
- The legacy web preview renderer remains in the repository as a rollback path while the MarkdownView migration is evaluated.

## Current Limitations

- Exact editor-to-preview scroll synchronization is not implemented for the native preview yet.
- Mermaid diagrams are not rendered in this phase; Mermaid fences remain visible as code blocks.
- The legacy `SharedRenderer` assets remain in the repository only as a rollback path while the native preview is evaluated.

## License

This project is licensed under the GNU General Public License v3.0 only.
See [LICENSE](LICENSE) for details.
