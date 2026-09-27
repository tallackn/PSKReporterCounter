import AppKit

@MainActor
final class ApplicationMenuController: NSObject {
    private let openSettings: () -> Void
    private let openGraphs: () -> Void
    private let openAbout: () -> Void
    private let openHelp: () -> Void

    init(openSettings: @escaping () -> Void, openGraphs: @escaping () -> Void,
         openAbout: @escaping () -> Void, openHelp: @escaping () -> Void) {
        self.openSettings = openSettings
        self.openGraphs = openGraphs
        self.openAbout = openAbout
        self.openHelp = openHelp
        super.init()
        let menu = NSMenu()
        let app = NSMenu()
        addItem("About PSK Reporter Counter", action: #selector(about), key: "", to: app)
        app.addItem(.separator())
        addItem("Settings…", action: #selector(settings), key: ",", to: app)
        app.addItem(.separator())
        addItem("Quit PSK Reporter Counter", action: #selector(quit), key: "q", to: app)
        addMenu(app, to: menu)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        addMenu(edit, to: menu)
        let window = NSMenu(title: "Window")
        addItem("Live Graphs", action: #selector(graphs), key: "g", to: window)
        window.addItem(.separator())
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(withTitle: "Minimise", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        addMenu(window, to: menu)
        let helpMenu = NSMenu(title: "Help")
        addItem("PSK Reporter Counter Help", action: #selector(help), key: "?", to: helpMenu)
        addMenu(helpMenu, to: menu)
        NSApp.mainMenu = menu
        NSApp.helpMenu = helpMenu
    }

    private func addMenu(_ submenu: NSMenu, to menu: NSMenu) {
        let item = NSMenuItem()
        item.submenu = submenu
        menu.addItem(item)
    }

    private func addItem(_ title: String, action: Selector, key: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    @objc private func settings() { openSettings() }
    @objc private func graphs() { openGraphs() }
    @objc private func about() { openAbout() }
    @objc private func help() { openHelp() }
    @objc private func quit() { NSApp.terminate(nil) }
}
