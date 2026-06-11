import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let overlay = OverlayController()
    private var statisticsWindow: NSWindow?

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
            openSettings: { [weak self] in self?.openSettings() })
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
            button.image = skylineImage()
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

    /// Small colored block in the in-progress design.
    private func designGlyph(_ design: BlockDesign) -> NSImage {
        let size = NSSize(width: 14, height: 11)
        let image = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
                                    xRadius: 2, yRadius: 2)
            NSColor(design.baseColor).setFill()
            path.fill()
            NSColor(design.accentColor).withAlphaComponent(0.9).setStroke()
            path.lineWidth = 1
            path.stroke()
            return true
        }
        image.isTemplate = false
        return image
    }

    /// Template-rendered mini-silhouette of the world's skyline for idle mode,
    /// so it adapts to the menu bar appearance.
    private func skylineImage() -> NSImage {
        let world = appState.world
        let size = NSSize(width: 18, height: 12)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            guard !world.blocks.isEmpty else {
                // Empty world: a single block outline placeholder.
                let block = NSRect(x: rect.midX - 4, y: 1, width: 8, height: 7)
                NSBezierPath(roundedRect: block, xRadius: 1.5, yRadius: 1.5).fill()
                return true
            }
            let columnWidth = rect.width / CGFloat(World.columns)
            let maxHeight = rect.height - 1
            for col in 0..<World.columns {
                let height = world.columnHeight(col)
                guard height > 0 else { continue }
                let barHeight = min(maxHeight,
                                    CGFloat(height) / CGFloat(World.rows) * maxHeight * 2)
                NSRect(x: CGFloat(col) * columnWidth, y: 0,
                       width: max(columnWidth - 0.4, 0.6), height: barHeight).fill()
            }
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

    private func openSettings() {
        popover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
