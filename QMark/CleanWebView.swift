import WebKit

/// 自定义 WKWebView，替换右键菜单为精简版
class CleanWebView: WKWebView {

    /// 是否为只读模式（预览区域），只读时不显示 Cut/Paste
    var isReadOnly: Bool = false

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        menu.removeAllItems()

        if !isReadOnly {
            menu.addItem(NSMenuItem(title: "Cut", action: Selector(("cut:")), keyEquivalent: ""))
        }
        menu.addItem(NSMenuItem(title: "Copy", action: Selector(("copy:")), keyEquivalent: ""))
        if !isReadOnly {
            menu.addItem(NSMenuItem(title: "Paste", action: Selector(("paste:")), keyEquivalent: ""))
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Select All", action: Selector(("selectAll:")), keyEquivalent: ""))

        super.willOpenMenu(menu, with: event)
    }
}
