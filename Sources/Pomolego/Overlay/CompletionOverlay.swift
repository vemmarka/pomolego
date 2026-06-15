import AppKit
import SwiftUI

/// Borderless, transparent, non-activating, click-through panel used for the
/// completion animation. It never becomes key, so it can't steal focus.
/// The app contains no audio code; this overlay is strictly visual.
private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayController {
    private var panel: OverlayPanel?
    private var dismissTask: Task<Void, Never>?

    /// Total time the overlay stays on screen before fading.
    private let displayDuration: TimeInterval = 1.9

    /// `anchor` is the status item button's frame in screen coordinates;
    /// used for the near-menu-bar position. `screen` decides which display
    /// hosts the centered variant.
    func show(event: OverlayEvent, anchor: NSRect?, screen: NSScreen?) {
        let position = AppSettings.animationPosition
        guard position != .off else { return }

        dismissTask?.cancel()
        panel?.orderOut(nil)

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let size = NSSize(width: 240, height: 120)
        let content = CompletionOverlayView(event: event, reduceMotion: reduceMotion)

        let panel = OverlayPanel(contentRect: NSRect(origin: .zero, size: size),
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false

        // Host the SwiftUI overlay with a fixed frame and no autolayout-driven
        // sizing. The overlay animates (scale/offset/confetti), and a bare
        // NSHostingView in a borderless panel will otherwise post window
        // constraint updates mid-animation, which AppKit turns into an
        // uncaught exception (_postWindowNeedsUpdateConstraints) and aborts.
        // sizingOptions = [] stops the hosting view from driving window layout.
        let hosting = NSHostingView(rootView: content)
        hosting.sizingOptions = []
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        panel.setFrameOrigin(origin(for: position, size: size,
                                    anchor: anchor, screen: screen))
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 1
        }

        self.panel = panel
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.displayDuration ?? 2))
            guard !Task.isCancelled else { return }
            self?.fadeOutAndClose()
        }
    }

    private func origin(for position: AnimationPosition, size: NSSize,
                        anchor: NSRect?, screen: NSScreen?) -> NSPoint {
        let targetScreen = screen ?? NSScreen.main
        switch position {
        case .nearMenuBarIcon:
            if let anchor {
                let x = anchor.midX - size.width / 2
                let y = anchor.minY - size.height - 6
                return clamped(NSPoint(x: x, y: y), size: size, on: targetScreen)
            }
            fallthrough
        case .centerOfScreen, .off:
            guard let frame = targetScreen?.visibleFrame else { return .zero }
            return NSPoint(x: frame.midX - size.width / 2,
                           y: frame.midY - size.height / 2)
        }
    }

    private func clamped(_ point: NSPoint, size: NSSize, on screen: NSScreen?) -> NSPoint {
        guard let frame = screen?.visibleFrame else { return point }
        return NSPoint(x: min(max(point.x, frame.minX), frame.maxX - size.width),
                       y: min(max(point.y, frame.minY), frame.maxY - size.height))
    }

    private func fadeOutAndClose() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            panel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor [weak self] in
                self?.panel?.orderOut(nil)
                self?.panel = nil
            }
        })
    }
}

// MARK: - Animation content

private struct Particle: Identifiable {
    let id: Int
    let angle: Double
    let distance: CGFloat
    let size: CGFloat
    let color: Color
}

struct CompletionOverlayView: View {
    let event: OverlayEvent
    let reduceMotion: Bool

    @State private var dropped = false
    @State private var settled = false
    @State private var burst = false

    private var design: BlockDesign? {
        if case .blockBuilt(let design) = event { return design }
        return nil
    }

    private var message: String {
        switch event {
        case .blockBuilt(let design): return "Block built — \(design.name)"
        case .breakOver: return "Break's over"
        }
    }

    private var particles: [Particle] {
        guard case .blockBuilt(let design) = event else { return [] }
        return (0..<8).map { i in
            Particle(id: i,
                     angle: Double(i) / 8 * 2 * .pi,
                     distance: 26 + CGFloat(i % 3) * 8,
                     size: 3 + CGFloat(i % 2) * 2,
                     color: i.isMultiple(of: 2) ? design.baseColor : design.accentColor)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if !reduceMotion {
                    ForEach(particles) { particle in
                        Circle()
                            .fill(particle.color)
                            .frame(width: particle.size, height: particle.size)
                            .offset(x: burst ? cos(particle.angle) * particle.distance : 0,
                                    y: burst ? sin(particle.angle) * particle.distance : 0)
                            .opacity(burst ? 0 : 0.9)
                    }
                }
                if let design {
                    BlockSwatch(design: design)
                        .frame(width: 36, height: 28)
                        .scaleEffect(x: settled ? 1 : 1.15,
                                     y: settled ? 1 : 0.82,
                                     anchor: .bottom)
                        .offset(y: dropped ? 0 : (reduceMotion ? 0 : -44))
                } else {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 44)
            Text(message)
                .font(.callout.weight(.semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onAppear(perform: animate)
        .accessibilityLabel(message)
    }

    private func animate() {
        if reduceMotion {
            // Fade-only: the panel itself fades in/out; content stays static.
            dropped = true
            settled = true
            return
        }
        withAnimation(.spring(duration: 0.45, bounce: 0.25)) {
            dropped = true
        }
        withAnimation(.spring(duration: 0.3).delay(0.4)) {
            settled = true
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.42)) {
            burst = true
        }
    }
}
