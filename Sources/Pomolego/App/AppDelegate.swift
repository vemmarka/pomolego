import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let overlay = OverlayController()
    private var statisticsWindow: NSWindow?
    private var albumWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        setUpPopover()

        appState.onStatusUpdate = { [weak self] in
            self?.updateStatusItem()
        }
        appState.onOverlay = { [weak self] event in
            guard let self else { return }
            overlay.show(event: event,
                         anchor: statusItemScreenFrame(),
                         screen: statusItem.button?.window?.screen)
        }
        updateStatusItem()
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageLeading
    }

    private func setUpPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        let root = MainPanelView(
            openStatistics: { [weak self] in self?.openStatistics() },
            openSettings: { [weak self] in self?.openSettings() },
            openAlbum: { [weak self] in self?.openAlbum() })
            .environmentObject(appState)
        popover.contentViewController = NSHostingController(rootView: root)
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
            return
        }
        togglePopover()
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Album",
                     action: #selector(menuOpenAlbum), keyEquivalent: "")
        menu.addItem(withTitle: "Statistics",
                     action: #selector(menuOpenStatistics), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…",
                     action: #selector(menuOpenSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Pomolego",
                     action: #selector(menuQuit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        // Temporarily attach the menu so it pops below the item, then detach
        // so left-clicks keep toggling the popover.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func menuOpenAlbum() { openAlbum() }
    @objc private func menuOpenStatistics() { openStatistics() }
    @objc private func menuOpenSettings() { openSettings() }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    private func statusItemScreenFrame() -> NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    /// Refresh the menu bar item for the current phase. Called on every tick
    /// (also while the popover is closed) and on every transition.
    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let showCountdown = AppSettings.menuBarShowsCountdown
        let countdown = appState.remaining.countdownString

        switch appState.phase {
        case .focusRunning, .focusPaused:
            button.image = designGlyph(appState.currentDesign)
            setTitle(showCountdown ? countdown : "", on: button)
            button.toolTip = "Focusing — \(countdown) left"
        case .breakRunning, .breakPaused:
            button.image = symbolImage("cup.and.saucer.fill")
            setTitle(showCountdown ? countdown : "", on: button)
            button.toolTip = "On a break — \(countdown) left"
        case .breakPrompt:
            button.image = symbolImage("cup.and.saucer")
            setTitle("", on: button)
            button.toolTip = "Break time — open Pomolego"
        case .idle:
            button.image = brickGlyph()
            setTitle("", on: button)
            button.toolTip = "Pomolego — \(appState.world.builtCount) blocks built"
        }
        button.setAccessibilityLabel(button.toolTip)
    }

    private func setTitle(_ title: String, on button: NSStatusBarButton) {
        guard !title.isEmpty else {
            button.attributedTitle = NSAttributedString(string: "")
            return
        }
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        button.attributedTitle = NSAttributedString(
            string: " " + title,
            attributes: [.font: font, .baselineOffset: 0.5])
    }

    private func symbolImage(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    /// LEGO-style brick: rounded body with two studs on top. Drawn into
    /// `rect` so the template idle glyph and the colored focus glyph match.
    private func drawBrick(in rect: NSRect) {
        let studHeight: CGFloat = rect.height * 0.28
        let body = NSRect(x: rect.minX, y: rect.minY,
                          width: rect.width, height: rect.height - studHeight)
        NSBezierPath(roundedRect: body, xRadius: 1.5, yRadius: 1.5).fill()
        let studWidth = rect.width * 0.26
        let inset = rect.width * 0.16
        for x in [rect.minX + inset, rect.maxX - inset - studWidth] {
            let stud = NSRect(x: x, y: body.maxY - 0.5,
                              width: studWidth, height: studHeight + 0.5)
            NSBezierPath(roundedRect: stud, xRadius: 1, yRadius: 1).fill()
        }
    }

    /// Small brick in the in-progress design's color.
    private func designGlyph(_ design: BlockDesign) -> NSImage {
        let size = NSSize(width: 15, height: 12)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor(design.baseColor).setFill()
            self.drawBrick(in: rect.insetBy(dx: 0.5, dy: 0.5))
            return true
        }
        image.isTemplate = false
        return image
    }

    /// Template-rendered brick for idle mode, adapting to the menu bar
    /// appearance.
    private func brickGlyph() -> NSImage {
        let size = NSSize(width: 15, height: 12)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            self.drawBrick(in: rect.insetBy(dx: 0.5, dy: 0.5))
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Windows

    private func openStatistics() {
        popover.performClose(nil)
        if statisticsWindow == nil {
            let hosting = NSHostingController(
                rootView: StatisticsView().environmentObject(appState))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Pomolego Statistics"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 560, height: 640))
            window.isReleasedWhenClosed = false
            window.center()
            statisticsWindow = window
        }
        statisticsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openAlbum() {
        popover.performClose(nil)
        if albumWindow == nil {
            let hosting = NSHostingController(
                rootView: AlbumView().environmentObject(appState))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Pomolego Album"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 600, height: 540))
            window.isReleasedWhenClosed = false
            window.center()
            albumWindow = window
        }
        albumWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openSettings() {
        popover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
