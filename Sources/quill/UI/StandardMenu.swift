import AppKit

/// Quill is a `ParsableCommand` daemon (see Quill.swift), not a standard
/// SwiftUI `App` or a nib-based AppKit app — nothing ever builds
/// `NSApp.mainMenu` for it otherwise. Without an Edit menu somewhere in
/// the menu bar carrying Cut/Copy/Paste/Select All/Undo/Redo with their
/// key equivalents, macOS has nothing to match ⌘C/⌘V/⌘X/⌘A against, so
/// those shortcuts silently do nothing in every text field across the
/// app (Feedback's body/email fields included) even though right-click →
/// Copy/Paste still works fine. This installs the same minimal Edit menu
/// every AppKit app gets for free from a MainMenu.xib, so the standard
/// shortcuts route to the field editor like anywhere else on macOS.
enum StandardMenu {
    @MainActor
    static func install() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "Quit Quill", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        )

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        // `undo:`/`redo:` are informal responder-chain actions (routed
        // through NSUndoManager), not declared on any SDK class, so they
        // need the string-selector form rather than `#selector`.
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }
}
