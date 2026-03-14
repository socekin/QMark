# QMark

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-black.svg)](#系统要求)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138.svg?logo=swift&logoColor=white)](#技术栈)
[![XcodeGen](https://img.shields.io/badge/XcodeGen-required-0A84FF.svg)](#构建)

基于 SwiftUI + WKWebView + CodeMirror 6 构建的原生 macOS Markdown 编辑器。

[简体中文](README.zh-CN.md) | [English](README.md)

## 功能

- **分栏视图**：左侧为 CodeMirror 6 编辑器，右侧为 markdown-it 实时预览
- **语法高亮**：编辑器和预览都支持 GitHub 风格的亮色/暗色主题
- **主题切换**：可跟随系统，或手动切换 Light / Dark，切换即时生效
- **滚动同步**：编辑器与预览区域滚动位置保持同步
- **快捷键**：`⌘B` 加粗、`⌘I` 斜体、`⌘K` 插入链接、`⌘F` 查找替换
- **可调分栏**：拖动分隔线调整编辑区与预览区比例
- **隐藏编辑器**：可折叠编辑区，进入更专注的阅读模式
- **QuickLook 扩展**：在 Finder 中按空格即可预览 Markdown 文件
- **富文本内容**：支持代码高亮、KaTeX 数学公式、Mermaid 图表、任务列表、脚注等
- **多格式支持**：`.md` / `.mdx` / `.rmd` / `.mdown` / `.mkd`

## 系统要求

- macOS 26.0+
- Xcode 26.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Node.js（仅在重新构建 CodeMirror bundle 时需要）

## 构建

```bash
# 安装 XcodeGen（如未安装）
brew install xcodegen

# 生成 Xcode 项目并构建
make build

# 构建并启动
make run

# 清理构建产物
make clean

# 重新构建 CodeMirror bundle（需要 Node.js）
make editor-libs

# 重新下载 markdown-it 等预览依赖
bash scripts/download-libs.sh
```

> **说明：** 构建前请先把 `project.yml` 中的 `DEVELOPMENT_TEAM` 改成你自己的 Apple Developer Team ID，或者将 `CODE_SIGN_STYLE` 改为 `Manual` 后自行配置签名。

## 架构

```
QMark/                      — 主应用（SwiftUI）
├── QMarkApp.swift           — 应用入口与菜单配置
├── ContentView.swift        — 分栏布局、工具栏和主题管理
├── CleanWebView.swift       — 清理右键菜单的 WKWebView 子类
├── MarkdownDocument.swift   — ReferenceFileDocument 文档模型
├── Editor/
│   └── EditorView.swift     — 封装 CodeMirror 6 的 NSViewRepresentable
└── Preview/
    ├── PreviewView.swift    — 封装 markdown-it 的 NSViewRepresentable
    └── PreviewBridge.swift  — Swift 与 JavaScript 的预览桥接

EditorRenderer/              — 编辑器 Web 资源
├── editor.html              — CodeMirror 的 HTML 外壳
├── editor.js                — CodeMirror 初始化、主题、快捷键和 Swift 桥接
├── editor.css               — 排版样式
└── libs/
    └── codemirror.min.js    — CodeMirror 6 bundle（由 esbuild 构建）

SharedRenderer/              — 预览 Web 资源
├── template.html            — 预览 HTML 模板
├── renderer.js              — 带插件的 markdown-it 初始化
├── style.css                — GitHub 风格预览样式（亮色/暗色）
└── libs/                    — markdown-it、KaTeX、highlight.js、Mermaid 等依赖

QMarkQuickLook/              — QuickLook 预览扩展
scripts/                     — JavaScript 依赖构建脚本
```

## 技术栈

| 模块 | 技术 |
|-----------|-----------|
| 编辑器 | WKWebView + [CodeMirror 6](https://codemirror.net/) |
| 预览 | WKWebView + [markdown-it](https://github.com/markdown-it/markdown-it) |
| 数学公式 | [KaTeX](https://katex.org/) |
| 图表 | [Mermaid](https://mermaid.js.org/) |
| 代码高亮 | [highlight.js](https://highlightjs.org/) |
| 文档模型 | ReferenceFileDocument |
| UI 框架 | SwiftUI |
| 项目生成 | [XcodeGen](https://github.com/yonaskolb/XcodeGen) |
| JS 打包 | [esbuild](https://esbuild.github.io/) |

## 许可证

本项目采用 GNU General Public License v3.0 only 授权。
详细内容见 [LICENSE](LICENSE)。
