# QMark

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-black.svg)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138.svg?logo=swift&logoColor=white)](#tech-stack)
[![XcodeGen](https://img.shields.io/badge/XcodeGen-required-0A84FF.svg)](#build)

A native macOS Markdown editor built with SwiftUI + WKWebView + CodeMirror 6.

[English](README.md) | [Simplified Chinese](README.zh-CN.md)

## Features

- **Split View** — CodeMirror 6 editor on the left, real-time markdown-it preview on the right
- **Syntax Highlighting** — GitHub-style light/dark themes for both editor and preview
- **Theme Switching** — Follow system, Light, or Dark mode with instant switching
- **Scroll Sync** — Editor and preview scroll positions stay in sync
- **Keyboard Shortcuts** — `⌘B` bold, `⌘I` italic, `⌘K` insert link, `⌘F` find/replace
- **Resizable Split** — Drag the divider to adjust editor/preview ratio
- **Toggle Editor** — Collapse the editor for a distraction-free reading mode
- **QuickLook Extension** — Preview Markdown files in Finder with spacebar
- **Rich Content** — Code highlighting, KaTeX math, Mermaid diagrams, task lists, footnotes, and more
- **Multi-format** — `.md` / `.mdx` / `.rmd` / `.mdown` / `.mkd`

## Requirements

- macOS 15.0+
- Xcode 16.0+
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

# Re-download markdown-it and other preview libraries
bash scripts/download-libs.sh
```

> **Note:** Before building, copy `Local.xcconfig.example` to `Local.xcconfig` and set your Apple Developer Team ID, or set `CODE_SIGN_STYLE` to `Manual` in `project.yml` and configure signing as needed.

## Architecture

```
QMark/                      — Main app (SwiftUI)
├── QMarkApp.swift           — App entry, menu configuration
├── ContentView.swift        — Split view layout, toolbar, theme management
├── CleanWebView.swift       — WKWebView subclass with clean context menus
├── MarkdownDocument.swift   — ReferenceFileDocument model
├── Editor/
│   └── EditorView.swift     — NSViewRepresentable wrapping CodeMirror 6
└── Preview/
    ├── PreviewView.swift    — NSViewRepresentable wrapping markdown-it
    └── PreviewBridge.swift  — Swift ↔ JavaScript bridge for preview

EditorRenderer/              — Editor web resources
├── editor.html              — HTML shell for CodeMirror
├── editor.js                — CodeMirror setup, themes, keyboard shortcuts, Swift bridge
├── editor.css               — Typography
└── libs/
    └── codemirror.min.js    — CodeMirror 6 bundle (built via esbuild)

SharedRenderer/              — Preview web resources
├── template.html            — Preview HTML template
├── renderer.js              — markdown-it initialization with plugins
├── style.css                — GitHub-style preview CSS (light/dark)
└── libs/                    — markdown-it, KaTeX, highlight.js, Mermaid, etc.

QMarkQuickLook/              — QuickLook preview extension
scripts/                     — Build scripts for JS dependencies
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Editor | WKWebView + [CodeMirror 6](https://codemirror.net/) |
| Preview | WKWebView + [markdown-it](https://github.com/markdown-it/markdown-it) |
| Math | [KaTeX](https://katex.org/) |
| Diagrams | [Mermaid](https://mermaid.js.org/) |
| Code Highlighting | [highlight.js](https://highlightjs.org/) |
| Document Model | ReferenceFileDocument |
| UI Framework | SwiftUI |
| Project Generation | [XcodeGen](https://github.com/yonaskolb/XcodeGen) |
| JS Bundling | [esbuild](https://esbuild.github.io/) |

## License

This project is licensed under the GNU General Public License v3.0 only.
See [LICENSE](LICENSE) for details.
