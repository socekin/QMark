# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Added

- Added `MarkdownView` as a pinned Swift Package dependency.
- Added a shared SwiftUI Markdown preview used by both the main app and Quick Look extension.
- Added local signing configuration support through `Local.xcconfig`.

### Changed

- Replaced the main app preview rendering path with the native MarkdownView-based renderer.
- Replaced the Quick Look preview rendering path with the shared native MarkdownView renderer.
- Kept legacy web preview assets in the repository as a rollback path during evaluation.

### Fixed

- Kept the Quick Look hosting view stable during preview generation.
- Restored the filled macOS app icon appearance in generated builds.

### Deferred

- Mermaid diagram rendering is deferred; Mermaid fenced blocks currently render as code blocks.
