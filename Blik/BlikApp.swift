import SwiftUI

@main
struct BlikApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var scheduler = Scheduler.shared
    @ObservedObject private var focus = FocusSession.shared

    var body: some Scene {
        MenuBarExtra {
            SettingsView()
                .environmentObject(AppSettings.shared)
                .environmentObject(Scheduler.shared)
                .environmentObject(FocusSession.shared)
        } label: {
            // During a focus session the icon gives way to the countdown.
            if let remaining = focus.remaining {
                Image(nsImage: MenuBarClock.image(FocusSession.clock(remaining)))
            } else {
                Image(systemName: scheduler.isPaused ? "eye.slash" : "eye")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

/// The countdown as a menu bar image. Drawn rather than set as text so the digits are all
/// the same width and the menu bar does not shuffle about every second.
enum MenuBarClock {
    static func image(_ text: String) -> NSImage {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.black
        ]
        let measured = (text as NSString).size(withAttributes: attributes)
        let size = NSSize(width: ceil(measured.width), height: ceil(measured.height))
        let image = NSImage(size: size, flipped: false) { _ in
            (text as NSString).draw(at: .zero, withAttributes: attributes)
            return true
        }
        // A template image takes the menu bar's own colour, light or dark.
        image.isTemplate = true
        return image
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Scheduler.shared.start()
        HotKey.shared.onPress = {
            FocusSession.shared.toggle()
        }
        HotKey.shared.bind(AppSettings.shared.focusHotKey)
    }
}
