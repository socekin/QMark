import SwiftUI

enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}

struct ContentView: View {
    @ObservedObject var document: MarkdownDocument
    @State private var markdownText: String = ""
    @State private var scrollPercentage: CGFloat = 0
    @State private var isEditorVisible: Bool = true
    @State private var editorWidthRatio: CGFloat = 0.5
    @State private var isDarkMode: Bool = false
    @AppStorage("appTheme") private var appTheme: String = AppTheme.system.rawValue

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appTheme) ?? .system
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                if isEditorVisible {
                    // 左侧：编辑器
                    EditorView(
                        document: document,
                        isDark: isDarkMode,
                        onTextChange: { text in
                            markdownText = text
                        },
                        onScrollChange: { percentage in
                            scrollPercentage = percentage
                        }
                    )
                    .frame(width: editorWidth(in: geo.size.width))

                    // 自定义可拖拽分割线，使用父容器坐标空间避免拖拽闪烁
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 3)
                        .frame(width: 7)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            if hovering {
                                NSCursor.resizeLeftRight.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 1, coordinateSpace: .named("splitView"))
                                .onChanged { value in
                                    let ratio = value.location.x / geo.size.width
                                    editorWidthRatio = max(0.2, min(0.8, ratio))
                                }
                        )
                }

                // 右侧：预览
                PreviewView(
                    markdown: markdownText,
                    scrollPercentage: scrollPercentage,
                    isDark: isDarkMode
                )
            }
            .coordinateSpace(name: "splitView")
        }
        .onAppear {
            markdownText = document.text
            applyTheme(selectedTheme)
        }
        .onChange(of: appTheme) {
            applyTheme(selectedTheme)
        }
        // 监听系统主题变更，"跟随系统"模式下需要重新设置显式外观
        .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))) { _ in
            if selectedTheme == .system {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    applyTheme(.system)
                }
            }
        }
        .frame(minWidth: isEditorVisible ? 700 : 400, minHeight: 500)
        .preferredColorScheme(selectedTheme.colorScheme)
        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        .toolbar {
            // 左侧：收起/展开编辑器
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation {
                        isEditorVisible.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                .help(isEditorVisible ? "收起编辑器" : "展开编辑器")
            }

            // 右侧：主题切换
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                        Button {
                            appTheme = theme.rawValue
                        } label: {
                            Label(theme.label, systemImage: theme.icon)
                        }
                        .disabled(selectedTheme == theme)
                    }
                } label: {
                    Image(systemName: selectedTheme.icon)
                }
                .help("切换主题")
            }
        }
    }

    private func editorWidth(in totalWidth: CGFloat) -> CGFloat {
        let width = totalWidth * editorWidthRatio
        return max(300, min(width, totalWidth - 300))
    }

    /// 始终设置显式 NSAppearance，并更新 isDarkMode 驱动编辑器主题切换
    private func applyTheme(_ theme: AppTheme) {
        let dark: Bool
        switch theme {
        case .system:
            dark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        case .light:
            dark = false
        case .dark:
            dark = true
        }
        isDarkMode = dark
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        NSApp.appearance = appearance
        // 强制所有窗口立即更新外观，确保预览区 WKWebView 的 CSS 媒体查询立即重新评估
        for window in NSApp.windows {
            window.appearance = appearance
        }
    }
}
