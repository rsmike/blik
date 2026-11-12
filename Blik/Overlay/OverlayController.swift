import AppKit
import SwiftUI

/// Borderless panel that floats above everything and never takes focus from the app you are working in.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The rest card's window. Unlike the other overlays it takes the keyboard, still without
/// activating Blik, so that a break can be answered with a key. Every plain key press goes to
/// `onKey` and nowhere else; shortcuts with Command are left to the system.
final class KeyPanel: NSPanel {
    var onKey: ((UInt16) -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, !event.modifierFlags.contains(.command) {
            if !event.isARepeat {
                onKey?(event.keyCode)
            }
            return
        }
        super.sendEvent(event)
    }
}

/// Lets a button respond to the very first click even though Blik is never the active app.
final class ClickableHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Puts things on screen: a toast on the display with the notch, with a dim on every display
/// if it is a reminder, or a rest break on all of them.
@MainActor
final class OverlayController {
    static let shared = OverlayController()

    private enum Showing {
        case toast, rest
    }

    private var showing: Showing?
    private var panels: [NSPanel] = []
    private var token = 0
    /// A toast that arrived while another was playing. Toasts never overlap: it plays next.
    private var waiting: ToastSpec?

    private init() {}

    /// Something is on screen, or about to be.
    var isShowing: Bool { showing != nil || waiting != nil }
    var isShowingRest: Bool { showing == .rest }

    func show(_ kind: ReminderKind) {
        if let toast = kind.toast {
            show(toast)
        } else {
            showRest()
        }
    }

    /// Plays a toast. One that arrives while another is playing waits for it to finish;
    /// one that arrives during a rest break takes the break down.
    func show(_ toast: ToastSpec) {
        if showing == .toast {
            waiting = toast
            return
        }
        takeDown(animated: true)
        guard let stage = stage else { return }

        token += 1
        let current = token
        showing = .toast
        if toast.dims && AppSettings.shared.dimScreen {
            for screen in NSScreen.screens {
                addOverlay(ToastDim(duration: toast.duration), on: screen)
            }
        }
        addOverlay(NotchScene(spec: toast, anchor: NotchAnchor(screen: stage)), on: stage)

        // A toast animates its own exit, so by now there is nothing left to see.
        after(toast.duration) { [weak self] in
            guard let self = self, self.token == current else { return }
            self.takeDown(animated: false)
            self.playWaiting()
        }
    }

    /// A rest break: the dim on every display, and the card on the one with the notch.
    /// It stays until one of the buttons on the card is pressed.
    private func showRest() {
        waiting = nil
        takeDown(animated: false)
        guard let stage = stage else { return }
        let settings = AppSettings.shared

        token += 1
        showing = .rest
        for screen in NSScreen.screens {
            let dim = RestBreakView(
                dimmed: settings.dimScreen,
                isPrimary: screen === stage,
                anchor: NotchAnchor(screen: screen)
            )
            addOverlay(dim, on: screen)
        }

        let size = RestCard.size
        let frame = CGRect(
            x: stage.frame.midX - size.width / 2,
            y: stage.frame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        let model = RestCardModel(
            candidates: settings.activitiesLeftToday(),
            onSnooze: { Scheduler.shared.snoozeRest() },
            onDone: { activity in
                if let activity = activity {
                    ActivityLog.markDone(activity)
                }
                Scheduler.shared.finishRest()
            }
        )
        let host = ClickableHostingView(rootView: RestCard(model: model))
        host.sizingOptions = []
        let above = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        let panel = KeyPanel(contentRect: frame, styleMask: Self.panelStyle, backing: .buffered, defer: false)
        configure(panel, clickThrough: false, level: above)
        panel.onKey = { [weak model] code in
            model?.key(code)
        }
        panel.contentView = host
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        // Enter, space and esc answer the break, so the card takes the keyboard while it is up.
        panel.makeKey()
        panels.append(panel)
    }

    /// Takes down whatever is on screen (done, snooze, pause). A toast that was waiting plays now.
    func dismiss(animated: Bool) {
        takeDown(animated: animated)
        playWaiting()
    }

    private func playWaiting() {
        guard let next = waiting else { return }
        waiting = nil
        show(next)
    }

    private func takeDown(animated: Bool) {
        showing = nil
        guard !panels.isEmpty else { return }
        token += 1
        let closing = panels
        panels = []

        guard animated else {
            closing.forEach { $0.orderOut(nil) }
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.45
            closing.forEach { $0.animator().alphaValue = 0 }
        }
        after(0.5) {
            closing.forEach { $0.orderOut(nil) }
        }
    }

    /// Toasts drop from the notch, so the content goes on the display that has one. Failing that,
    /// on the system's primary display (the one set as main in Displays settings, always first).
    private var stage: NSScreen? {
        let screens = NSScreen.screens
        return screens.first(where: NotchAnchor.hasNotch) ?? screens.first
    }

    /// A click-through, full-screen window on one display.
    private func addOverlay<Content: View>(_ view: Content, on screen: NSScreen) {
        let host = NSHostingView(rootView: view)
        host.sizingOptions = []
        let panel = OverlayPanel(contentRect: screen.frame, styleMask: Self.panelStyle, backing: .buffered, defer: false)
        configure(panel, clickThrough: true, level: .screenSaver)
        panel.contentView = host
        panel.setFrame(screen.frame, display: true)
        panel.orderFrontRegardless()
        panels.append(panel)
    }

    private static let panelStyle: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]

    private func configure(_ panel: NSPanel, clickThrough: Bool, level: NSWindow.Level) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = level
        panel.ignoresMouseEvents = clickThrough
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        // Blik is never the active app; without this the panel would hide itself immediately.
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.animationBehavior = .none
    }

    private func after(_ seconds: Double, _ work: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            work()
        }
    }
}
