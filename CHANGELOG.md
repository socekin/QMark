# Changelog

All notable changes to this project will be documented in this file.

## 1.2 - 2026-06-30

### Added

- Added `MarkdownView` as a pinned Swift Package dependency.
- Added a shared SwiftUI Markdown preview used by both the main app and Quick Look extension.
- Added local signing configuration support through `Local.xcconfig`.
- Added local Markdown performance fixtures for app and Quick Look smoke testing.

### Changed

- Replaced the main app preview rendering path with the native MarkdownView-based renderer.
- Replaced the Quick Look preview rendering path with the shared native MarkdownView renderer.
- Open Markdown documents in preview mode by default and lazy-load the editor only when editing is enabled.
- Stream MarkdownView preview updates for app and Quick Look previews to keep larger files responsive.
- Debounce editor-driven preview updates based on document size.
- Kept legacy web preview assets in the repository as a rollback path during evaluation.

### Fixed

- Kept the Quick Look hosting view stable during preview generation.
- Avoided repeated Quick Look Markdown decoding after the preview source is installed.
- Restored bidirectional percentage-based scroll synchronization between the editor and preview.
- Restored the filled macOS app icon appearance in generated builds.
- Disabled stale document restoration after normal close or quit while preserving system-initiated restore support.

### Deferred

- Mermaid diagram rendering is deferred; Mermaid fenced blocks currently render as code blocks.
