import ServiceManagement
import SwiftUI

/// The pop-up under the menu bar icon. The only window Blik has.
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var scheduler: Scheduler

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            VStack(spacing: 10) {
                ForEach(ReminderKind.allCases) { kind in
                    ReminderRow(kind: kind)
                }
            }
            Divider()
            FocusSection()
            Divider()
            options
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 10) {
            TimelineView(.animation) { timeline in
                EyeGlyph(
                    openness: scheduler.isPaused ? 0.06 : blinkOpenness(timeline.date.timeIntervalSinceReferenceDate, period: 3.6),
                    color: .primary,
                    size: 30
                )
            }
            .frame(width: 32, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "Blik")
                    .font(.system(size: 14, weight: .semibold))
                Text(verbatim: scheduler.isPaused ? "Paused until 5 AM" : "Looking after your eyes")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 10) {
            optionRow("Dim screen during reminders", isOn: $settings.dimScreen)
            optionRow("Launch at login", isOn: launchBinding)
            activitiesField
        }
    }

    private var activitiesField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "Off-screen activities")
                .font(.system(size: 13))
            TextField("juggle, read, meditate", text: $settings.activitiesText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .lineLimit(1...4)
            Text(verbatim: "Separated by commas. A rest break suggests one you have not done today.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func optionRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(verbatim: title)
                .font(.system(size: 13))
            Spacer()
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
    }

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { @MainActor in launchAtLogin },
            set: { @MainActor wanted in
                do {
                    if wanted {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    NSLog("Blik: could not change the login item: \(error.localizedDescription)")
                }
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        )
    }

    private var footer: some View {
        HStack {
            Button {
                if scheduler.isPaused {
                    scheduler.resume()
                } else {
                    scheduler.pauseForToday()
                }
            } label: {
                Label(
                    scheduler.isPaused ? "Resume" : "Pause for today",
                    systemImage: scheduler.isPaused ? "play.fill" : "pause.fill"
                )
            }
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .controlSize(.regular)
    }
}

/// The focus session: its length, a button to start and stop it, and its system-wide shortcut.
private struct FocusSection: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var focus: FocusSession

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: "Focus")
                        .font(.system(size: 13, weight: .semibold))
                    Text(verbatim: focus.remaining.map { FocusSession.clock($0) + " left" } ?? "Holds the rest break back")
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Picker("Session length", selection: $settings.focusMinutes) {
                    ForEach(AppSettings.focusOptions, id: \.self) { value in
                        Text(verbatim: "\(value) min").tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .fixedSize()
                .disabled(focus.isActive)

                Button(focus.isActive ? "Stop" : "Start") {
                    focus.toggle()
                }
                .controlSize(.small)
            }

            HStack {
                Text(verbatim: "Start / stop shortcut")
                    .font(.system(size: 13))
                Spacer()
                HotKeyRecorder()
            }
        }
    }
}

/// Shows the focus shortcut. Click it, then press the new one. Esc cancels.
private struct HotKeyRecorder: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var hotKey = HotKey.shared

    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            if hotKey.refused && !recording {
                Text(verbatim: "in use")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .help("The system would not register this shortcut. Something else may be using it.")
            }
            Button {
                if recording {
                    stop()
                } else {
                    begin()
                }
            } label: {
                Text(verbatim: recording ? "Press keys…" : settings.focusHotKey?.label ?? "None")
                    .frame(minWidth: 64)
            }
            .controlSize(.small)
            .help("Click, then press a shortcut that includes Control or Command")

            if settings.focusHotKey != nil && !recording {
                Button {
                    settings.focusHotKey = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Remove the shortcut")
            }
        }
        .onDisappear(perform: stop)
    }

    private func begin() {
        recording = true
        // Let go of the current shortcut so that pressing it again records it instead of firing it.
        HotKey.shared.release()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stop()
            } else if let combo = HotKeyCombo(event: event) {
                stopListening()
                settings.focusHotKey = combo
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    /// Ends recording and puts the shortcut that is set back in force.
    private func stop() {
        guard recording else { return }
        stopListening()
        HotKey.shared.bind(settings.focusHotKey)
    }

    private func stopListening() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        recording = false
    }
}

private struct ReminderRow: View {
    let kind: ReminderKind

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var scheduler: Scheduler
    @EnvironmentObject private var focus: FocusSession

    var body: some View {
        let isOn = settings.isEnabled(kind)
        HStack(spacing: 10) {
            Image(systemName: kind.symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )
                .opacity(isOn ? 1 : 0.45)

            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: kind.title)
                    .font(.system(size: 13, weight: .semibold))
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    Text(verbatim: status(at: timeline.date))
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .help(kind.detail)

            Spacer(minLength: 4)

            Picker("Interval", selection: minutesBinding) {
                ForEach(kind.intervalOptions, id: \.self) { value in
                    Text(verbatim: "\(value) min").tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .fixedSize()
            .disabled(!isOn)

            Button {
                OverlayController.shared.show(kind)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .help("Preview")

            Toggle(kind.title, isOn: enabledBinding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { @MainActor in settings.isEnabled(kind) },
            set: { @MainActor value in settings.enabled[kind] = value }
        )
    }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { @MainActor in settings.minutes[kind] ?? kind.defaultMinutes },
            set: { @MainActor value in settings.minutes[kind] = value }
        )
    }

    private func status(at date: Date) -> String {
        guard settings.isEnabled(kind) else { return "Off" }
        guard let due = scheduler.nextFire(kind) else { return "Paused" }
        // A focus session holds the rest break back until it ends.
        if kind == .rest, let focusEnds = focus.endsAt, due <= focusEnds {
            return "After focus"
        }
        let seconds = max(0, Int(due.timeIntervalSince(date).rounded()))
        if seconds == 0 { return "Any moment" }
        let minutes = seconds / 60
        let rest = seconds % 60
        return "in " + String(minutes) + ":" + (rest < 10 ? "0" : "") + String(rest)
    }
}
