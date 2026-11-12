import SwiftUI

@main
struct BlikApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var scheduler = Scheduler.shared

    var body: some Scene {
        MenuBarExtra {
            SettingsView()
                .environmentObject(AppSettings.shared)
                .environmentObject(Scheduler.shared)
        } label: {
            Image(systemName: scheduler.isPaused ? "eye.slash" : "eye")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Scheduler.shared.start()
    }
}
