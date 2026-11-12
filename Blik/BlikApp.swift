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
                    .renderingMode(.original)
            } else {
                Image(systemName: scheduler.isPaused ? "eye.slash" : "eye")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

/// The countdown as a menu bar image: white digits on a red badge with a white rim, so a
/// running session is hard to miss. The two colours cover for each other: over a light or dark
/// menu bar the red stands out, and over a red or orange wallpaper the white rim and digits do.
/// Drawn rather than set as text so the digits are all the same width and the menu bar does
/// not shuffle about every second.
enum MenuBarClock {
    private static let red = NSColor(srgbRed: 0.90, green: 0.16, blue: 0.16, alpha: 1)
    private static let rim: CGFloat = 1.5

    static func image(_ text: String) -> NSImage {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let measured = (text as NSString).size(withAttributes: attributes)
        let size = NSSize(width: ceil(measured.width) + 16, height: 19)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
            red.setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: rim, dy: rim), xRadius: 6 - rim, yRadius: 6 - rim).fill()
            let origin = NSPoint(x: (rect.width - measured.width) / 2, y: (rect.height - measured.height) / 2 + 0.5)
            (text as NSString).draw(at: origin, withAttributes: attributes)
            return true
        }
        // Not a template: the menu bar must leave its colours alone.
        image.isTemplate = false
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
