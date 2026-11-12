import AppKit
import SwiftUI

/// Borderless panel that floats above everything and never takes focus from the app you are working in.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Lets a button respond to the very first click even though Blik is never the active app.
final class ClickableHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Puts reminders on screen: one click-through, full-screen window per display.
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
        let pointer = NSEvent.mouseLocation
        let primary = screens.first { NSMouseInRect(pointer, $0.frame, false) } ?? NSScreen.main ?? screens[0]

        let settings = AppSettings.shared
        let theme = settings.theme
        let message = kind.randomMessage()

        token += 1
        let current = token
        isShowing = true

        for screen in screens {
            let scene = ReminderScene(
                kind: kind,
                theme: theme,
                dimmed: settings.dimScreen,
                isPrimary: screen === primary,
                message: message
            )
            let host = NSHostingView(rootView: scene)
            host.sizingOptions = []
            let panel = makePanel(frame: screen.frame, clickThrough: true, level: .screenSaver)
            panel.contentView = host
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            panels.append(panel)
        }

        if kind == .rest {
            let size = CGSize(width: 160, height: 56)
            let frame = CGRect(
                x: primary.frame.midX - size.width / 2,
                y: primary.visibleFrame.minY + 36,
                width: size.width,
                height: size.height
            )
            let button = SkipButton(theme: theme) { [weak self] in
                self?.dismiss(animated: true)
            }
            let host = ClickableHostingView(rootView: button)
            host.sizingOptions = []
            let above = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
            let panel = makePanel(frame: frame, clickThrough: false, level: above)
            panel.contentView = host
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
            panels.append(panel)
        }

        // Scenes animate their own exit, so by now there is nothing left to see.
        after(kind.duration) { [weak self] in
            guard let self = self, self.token == current else { return }
            self.dismiss(animated: false)
        }
    }

    /// Takes the current reminder down. Animated dismissal is for cutting one short (skip, pause).
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

    private func makePanel(frame: CGRect, clickThrough: Bool, level: NSWindow.Level) -> NSPanel {
        let panel = OverlayPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
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
        return panel
    }

    private func after(_ seconds: Double, _ work: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            work()
        }
    }
}
