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

/// Puts reminders on screen: one click-through, full-screen window per display,
/// plus the card of a rest break.
@MainActor
final class OverlayController {
    static let shared = OverlayController()

    private(set) var isShowing = false
    private var panels: [NSPanel] = []
    private var token = 0

    private init() {}

    func show(_ kind: ReminderKind) {
        dismiss(animated: false)

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let settings = AppSettings.shared

        // Reminders drop from the notch, so the content goes on the display that has one. Failing
        // that, on the system primary display (the one set as main in Displays settings, always first).
        let primary = screens.first(where: NotchAnchor.hasNotch) ?? screens[0]
        // A quick reminder lives on its own display and never dims anything.
        let toast = kind != .rest

        token += 1
        let current = token
        isShowing = true

        for screen in toast ? [primary] : screens {
            let scene = ReminderScene(
                kind: kind,
                dimmed: settings.dimScreen && !toast,
                isPrimary: screen === primary,
                anchor: NotchAnchor(screen: screen)
            )
            let host = NSHostingView(rootView: scene)
            host.sizingOptions = []
            let panel = makePanel(frame: screen.frame, clickThrough: true, level: .screenSaver)
            panel.contentView = host
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            panels.append(panel)
        }

        guard kind == .rest else {
            // Quick reminders animate their own exit, so by now there is nothing left to see.
            after(kind.duration) { [weak self] in
                guard let self = self, self.token == current else { return }
                self.dismiss(animated: false)
            }
            return
        }

        // A rest break stays until one of the buttons on its card is pressed.
        let size = RestCard.size
        let frame = CGRect(
            x: primary.frame.midX - size.width / 2,
            y: primary.frame.midY - size.height / 2,
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

    /// Takes the current reminder down. Animated dismissal is for one that is on screen (done, snooze, pause).
    func dismiss(animated: Bool) {
        guard !panels.isEmpty else {
            isShowing = false
            return
        }
        token += 1
        let closing = panels
        panels = []
        isShowing = false

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

    private static let panelStyle: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]

    private func makePanel(frame: CGRect, clickThrough: Bool, level: NSWindow.Level) -> NSPanel {
        let panel = OverlayPanel(contentRect: frame, styleMask: Self.panelStyle, backing: .buffered, defer: false)
        configure(panel, clickThrough: clickThrough, level: level)
        return panel
    }

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
