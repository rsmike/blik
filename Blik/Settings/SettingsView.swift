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
            optionRow("Dim screen during rest breaks", isOn: $settings.dimScreen)
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

private struct ReminderRow: View {
    let kind: ReminderKind

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var scheduler: Scheduler

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
        let seconds = max(0, Int(due.timeIntervalSince(date).rounded()))
        if seconds == 0 { return "Any moment" }
        let minutes = seconds / 60
        let rest = seconds % 60
        return "in " + String(minutes) + ":" + (rest < 10 ? "0" : "") + String(rest)
    }
}
