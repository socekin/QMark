# MarkdownView Preview Refactor Design

## Summary

Replace QMark's Markdown preview renderer with `LiYanan2004/MarkdownView`, pinned to the current `main` commit `82cf1bba9d2c5fdf52d895506e4142fcbbcfe157`.

The first migration should validate the native SwiftUI preview experience without Mermaid support. Mermaid code fences will render as normal code blocks for now. The existing CodeMirror editor remains unchanged.

## Goals

- Replace the main app preview from `WKWebView + markdown-it` with a SwiftUI preview built on `MarkdownView`.
- Reuse the same SwiftUI preview component in the Quick Look extension.
- Preserve the existing macOS-native app structure, window layout, toolbar, theme switcher, document model, and editor.
- Preserve Quick Look support for the existing Markdown-related file types.
- Keep Markdown editing and live preview responsive enough for interactive use.
- Make the migration easy to roll back while the MarkdownView experience is evaluated.

## Non-Goals

- Do not implement Mermaid rendering in this phase.
- Do not rewrite the CodeMirror editor.
- Do not remove `SharedRenderer` or the existing web preview assets in the first migration.
- Do not attempt full compatibility with all current `markdown-it` plugins.
- Do not redesign the app UI beyond the preview renderer replacement.
- Do not change document read/write behavior or supported file type declarations.

## Current State

QMark currently has three rendering-related surfaces:

- `QMark/Editor/EditorView.swift`: wraps CodeMirror in `WKWebView` for editing.
- `QMark/Preview/PreviewView.swift`: wraps `WKWebView` and loads `SharedRenderer/template.html`.
- `QMarkQuickLook/PreviewViewController.swift`: builds a self-contained HTML document and renders it in `WKWebView`.

The main app and Quick Look currently duplicate Markdown rendering logic. Both rely on `SharedRenderer`, `markdown-it`, KaTeX, highlight.js, Mermaid, and multiple markdown-it plugins.

## Recommended Approach

Use a shared SwiftUI preview component for both the main app and Quick Look.

The editor remains web-based. Only the Markdown preview renderer changes.

Main app data flow:

1. CodeMirror editor updates `MarkdownDocument.text`.
2. `ContentView` passes the current Markdown string to `QMarkMarkdownPreview`.
3. `QMarkMarkdownPreview` renders the content through MarkdownView.

Quick Look data flow:

1. `PreviewViewController` reads the selected file.
2. The controller creates `QMarkMarkdownPreview` with the file content.
3. The controller hosts the SwiftUI preview with `NSHostingView`.

Mermaid code fences are not rendered as diagrams in this phase. They should remain visible as fenced code blocks so documents do not fail or display blank content.

## Dependency Plan

Add a Swift Package dependency to `project.yml`:

- Package URL: `https://github.com/LiYanan2004/MarkdownView.git`
- Requirement: exact revision `82cf1bba9d2c5fdf52d895506e4142fcbbcfe157`
- Product: `MarkdownView`
- Toolchain requirement: Xcode 26.0+ / Swift tools 6.2+, because the pinned MarkdownView package declares `swift-tools-version: 6.2`.

Attach the package product to both targets:

- `QMark`
- `QMarkQuickLook`

This commit is from MarkdownView `main`, not a tagged release. After MarkdownView 3 ships as a stable tag, replace the revision pin with a version requirement.

## Architecture

### Shared Preview Component

Create a reusable SwiftUI component:

- Suggested path: `SharedPreview/QMarkMarkdownPreview.swift`, or `QMark/Preview/QMarkMarkdownPreview.swift` if XcodeGen target sharing is easier to manage initially.
- Inputs:
  - `markdown: String`
  - `isDark: Bool`
  - optional `baseURL: URL?`
- Output:
  - A SwiftUI view that renders Markdown content with `MarkdownView`.

The component owns preview-specific styling and MarkdownView modifiers:

- `markdownMathRenderingEnabled()`
- `markdownLinksUnderlined()`
- `markdownTableStyle(...)`
- `markdownBlockQuoteStyle(...)`
- `markdownCodeBlockStyle(...)` if custom styling is needed
- `markdownBaseURL(...)` when a document URL is available

### Main App Preview

Replace `QMark/Preview/PreviewView.swift` with either:

- a pure SwiftUI `PreviewView`, or
- a thin compatibility wrapper that delegates to `QMarkMarkdownPreview`.

The main app should continue passing:

- `markdown`
- `isDark`
- the current editor scroll percentage

Scroll synchronization should be treated as best-effort in phase one. The existing percentage-based JS bridge will no longer exist. If the first native preview does not support exact scroll sync, keep editor-to-preview sync out of scope and document it as a follow-up.

### Quick Look Preview

Replace the Quick Look WebView pipeline with `NSHostingView`.

`PreviewViewController.preparePreviewOfFile(at:completionHandler:)` should:

1. Read the Markdown file as UTF-8.
2. Create `QMarkMarkdownPreview(markdown:isDark:baseURL:)`.
3. Assign `self.view = NSHostingView(rootView: preview)`.
4. Call the completion handler.

Quick Look should keep the existing `QLSupportedContentTypes` and imported UTI declarations.

## Styling Requirements

The first pass should aim for a clean native macOS reading surface rather than a pixel-perfect clone of GitHub markdown CSS.

Required styling:

- Use system background and text colors.
- Support light and dark appearance.
- Keep readable content width and comfortable line spacing.
- Use native link tint and underline links.
- Keep code blocks visually distinct.
- Keep blockquotes, tables, headings, and task lists readable.

The preview should avoid web-specific CSS assumptions. Native SwiftUI layout should own spacing and theming.

## Feature Coverage

Expected first-pass support:

- Headings
- Paragraphs
- Bold, italic, strikethrough
- Links
- Images supported by MarkdownView
- Ordered and unordered lists
- Task lists
- Tables
- Blockquotes
- Inline code
- Fenced code blocks
- Syntax-highlighted code blocks on macOS
- Inline and display math supported by MarkdownView
- HTML blocks as supported by MarkdownView

Known first-pass differences from the current renderer:

- Mermaid diagrams render as code blocks.
- `markdown-it` plugin extensions such as deflist, mark, subscript, superscript, and generated TOC may not match current behavior.
- Exact GitHub CSS spacing and typography are not guaranteed.
- Scroll synchronization may need a separate native implementation.

## Quick Look Requirements

Quick Look must:

- Open supported Markdown file extensions without crashing.
- Render the same shared preview component as the main app.
- Respect light and dark system appearance.
- Avoid depending on the main app process.
- Avoid duplicating Markdown rendering logic.

Quick Look should not:

- Execute the old self-contained markdown-it HTML renderer.
- Load Mermaid or other web renderer resources in this phase.

## Error Handling

- If a file cannot be read in Quick Look, return an `NSError` through the completion handler.
- If Markdown content is invalid or includes unsupported extensions, render the readable portions rather than failing the whole preview.
- Unsupported code block languages should display as plain code blocks.
- Remote image loading should follow MarkdownView's default behavior for now; stricter image policy can be evaluated separately.

## Testing Plan

Build verification:

- `xcodegen generate`
- `xcodebuild -project QMark.xcodeproj -scheme QMark -configuration Debug -derivedDataPath build build CODE_SIGNING_ALLOWED=NO`

Manual app checks:

- Open a Markdown file.
- Edit text and confirm preview updates.
- Toggle light, dark, and system theme.
- Confirm links open in the system browser.
- Confirm common Markdown elements render correctly.
- Confirm Mermaid fences display as code blocks.

Manual Quick Look checks:

- Build and run the app once so the extension is available.
- Use Finder Quick Look on `.md`, `.markdown`, `.mdx`, `.rmd`, `.mdown`, and `.mkd` samples.
- Confirm the preview opens and uses the native renderer.
- Confirm dark mode appearance is acceptable.

Regression samples:

- Basic prose and headings
- Lists and task lists
- Tables
- Code blocks
- Math expressions
- Local and remote images
- Links
- Mermaid fenced code block
- Large Markdown document

## Rollback Plan

Keep the existing `SharedRenderer` directory and old renderer files during the first migration.

If MarkdownView preview quality is not acceptable, revert only:

- package dependency changes
- new shared preview component
- main preview replacement
- Quick Look preview replacement

The old web renderer assets remain available for a direct rollback.

## Follow-Up Work

- Decide whether to remove `SharedRenderer` after MarkdownView preview is accepted.
- Add Mermaid support through a custom MarkdownView code block style if needed.
- Revisit native scroll synchronization between editor and preview.
- Evaluate whether `MarkdownText` is better than `MarkdownView` for selection-heavy reading.
- Replace the `main` commit pin with a stable MarkdownView 3 release tag when available.
- Update README and third-party license documentation after the renderer choice is finalized.

## Open Questions

- Should the first implementation prioritize `MarkdownView` or `MarkdownText` for the preview surface?
- Should editor-to-preview scroll sync be removed temporarily or replaced with a native approximation in the same change?
- Should Quick Look disable remote image loading for stricter sandbox behavior?
