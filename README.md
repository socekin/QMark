# QMark

macOS 原生 Markdown 编辑器，基于 SwiftUI + WKWebView + CodeMirror 6 构建。

## 功能

- **左右分栏**：左侧 CodeMirror 6 编辑器，右侧 markdown-it 实时预览
- **Markdown 语法高亮**：编辑器内置语法高亮 + 代码块内嵌语言支持
- **行号显示**
- **查找替换**：⌘F 打开 CodeMirror 内置搜索面板
- **快捷键**：⌘B 加粗、⌘I 斜体、⌘K 插入链接
- **亮暗主题**：自动跟随系统外观
- **滚动同步**：编辑器与预览联动
- **QuickLook 扩展**：Finder 中按空格预览 Markdown 文件
- **多格式支持**：.md / .mdx / .rmd / .mdown / .mkd

## 系统要求

- macOS 26.0+
- Xcode 16.0+
- Node.js（仅在重新构建 CodeMirror bundle 时需要）

## 构建

```bash
# 生成 Xcode 项目并构建
make build

# 构建并运行
make run

# 清理
make clean

# 重新构建 CodeMirror bundle（需要 Node.js）
make editor-libs
```

## 架构

```
QMark/                  — 主应用 (SwiftUI)
├── QMarkApp.swift      — App 入口
├── ContentView.swift   — HSplitView 左右分栏
├── MarkdownDocument.swift — ReferenceFileDocument
├── Editor/
│   └── EditorView.swift   — WKWebView + CodeMirror 6
└── Preview/
    ├── PreviewView.swift  — WKWebView + markdown-it
    └── PreviewBridge.swift

EditorRenderer/         — 编辑器 Web 资源
├── editor.html         — HTML 模板
├── editor.js           — CodeMirror 初始化 + Swift 桥接
├── editor.css          — 主题 + 排版
└── libs/
    └── codemirror.min.js — CodeMirror 6 打包 bundle

SharedRenderer/         — 预览 Web 资源 (markdown-it)
QMarkQuickLook/         — QuickLook 预览扩展
```

## 技术栈

| 模块 | 技术 |
|------|------|
| 编辑器 | WKWebView + CodeMirror 6 |
| 预览 | WKWebView + markdown-it |
| 文档模型 | ReferenceFileDocument + @Published |
| UI 框架 | SwiftUI |
| 项目生成 | XcodeGen (`project.yml`) |
| JS 打包 | esbuild |

## License

MIT
