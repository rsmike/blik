# Blik

A tiny macOS menu bar app that reminds you to blink, fix your posture and take a proper break
(look away, water, stretch, something off-screen), with a simple focus timer built in.
No Dock icon, no windows - only the pop-up under the eye icon.

## Run it

1. Open `Blik.xcodeproj` in Xcode 16 or newer.
2. Press Cmd+R. An eye appears in the menu bar.
3. Click it and use the small play buttons to preview each reminder.

Requires macOS 14+. Signing is set to "Sign to Run Locally", so no developer account is needed.

To keep it around, install a Release build (see below) and switch on "Launch at login" in the
pop-up.

## Install and release

With Homebrew, on an Apple silicon Mac:

    brew install --cask rsmike/tap/blik

From source, `scripts/release.sh` does the work:

| Command                                | What it does                                              |
|----------------------------------------|-----------------------------------------------------------|
| `scripts/release.sh build [version]`   | Release build and a zip of it, in `build/`.               |
| `scripts/release.sh install`           | Release build, copied to `/Applications` and launched.    |
| `scripts/release.sh publish <version>` | Release build, GitHub release `v<version>` with the zip, and the Homebrew cask in `rsmike/homebrew-tap` updated to match. |

`publish` wants a clean working tree that is already pushed, and needs the `gh` command signed
in. The cask it writes comes from `packaging/blik.rb.template`.

Blik is signed to run locally and is not notarized. A copy you build yourself opens normally.
A downloaded copy is quarantined by macOS, so the cask removes the quarantine flag after
installing; if you download the zip by hand, do the same with
`xattr -dr com.apple.quarantine /Applications/Blik.app`.

## How it behaves

- Reminders are full-screen, click-through overlays above everything, including full-screen apps.
  Blink and posture never take keyboard focus. A rest break does, for its keys, without
  bringing Blik to the front; only its list and buttons accept clicks.
- A blink reminder holds its message for 4 seconds, a posture reminder for 2. How a reminder
  arrives and leaves takes the same time for both.
- Reminders are held back while you are away from the keyboard (2+ minutes of no input).
  An absence of 5+ minutes, or the Mac sleeping, restarts all intervals.
- A rest break stays on screen until you press "done" or "snooze"; nothing else fires meanwhile.
  "done" restarts all intervals. "snooze" brings the break back in 5 minutes.
- Rest break keys: Enter is "done", Esc is "snooze", Space picks a different activity, Delete
  turns the activity down. They are ignored for the first two seconds, so typing already under
  way does not answer the break.
- "Pause for today" lasts until 5 AM and survives a relaunch.

## What a reminder looks like

A drop of black liquid falls out of the notch and spreads into a small pill that types one word,
holds it, backspaces it, then gathers itself and goes back up. Nothing is dimmed.

For a rest break the drop falls to the middle of the screen and spreads into the dim, and a short
to-do list types itself out: look far away, drink water, stretch, and one off-screen activity.

- The activity is picked at random from the list you keep in the pop-up ("Off-screen activities",
  separated by commas). Click it to get a different one.
- Pressing "done" counts the activity shown as done for today, and it is not offered again until
  the next day. Blik's day runs from 5 AM to 5 AM. Once every activity is done the line is left out.
- To rest without doing the activity, click the cross next to it (or press Delete). The line
  turns into "no activity", "done" then counts nothing, and the activity stays open for today.
  Space brings an activity back. The same goes for a break you do not need at all: turn the
  activity down and press "done".

Reminders play on the display that has the notch. If no display has one (lid closed, older Mac),
the drop comes out of the top edge of the primary display instead.

## Focus sessions

A focus session is a countdown you start and stop with a system-wide shortcut (Control+Option+F
unless you change it) or with the Start button in the pop-up. Set its length and the shortcut
under "Focus" in the pop-up. A shortcut has to include Control or Command.

- Starting and stopping each play a short chime and drop a toast from the notch ("focus on.",
  "focus off."). The session also stops by itself when the time is up.
- While it runs, the menu bar icon is replaced by the time left (MM:SS): white digits on a red
  badge with a white rim, so it stands out over any wallpaper, red ones included.
- Blink and posture carry on. The rest break is held back, but its due time does not move:
  - it came due during the session: it shows as soon as the session ends, whether the time ran
    out or you stopped it;
  - it is not due yet when the session ends: it shows in its own time.
- A rest break that is already on screen when you start a session is taken down and comes back
  when the session ends.
- During a session you are taken to be at the computer even without touching it, so reading
  for twenty minutes does not count as being away.
- Toasts never overlap. One that arrives while another is playing waits for it to finish, so
  "focus off." is followed by the rest break, not covered by it.

## Layout

```
Blik/
  BlikApp.swift              entry point, menu bar item
  Core/
    ReminderKind.swift       the three reminders, texts, durations
    AppSettings.swift        persisted settings (UserDefaults)
    Scheduler.swift          when things fire: intervals, pause, snooze, focus, idle and sleep handling
    Focus.swift              the focus session and its countdown
    HotKey.swift             the system-wide shortcut
    Chime.swift              the start and stop sounds, synthesised
    Toast.swift              what a notch toast says and how long it stays
    Day.swift                the 5 AM day boundary, which activities were done today
    Motion.swift             easing and timing helpers
  Overlay/
    OverlayController.swift  the overlay windows
    Glyphs.swift             animated eye, posture figure
  Scenes/
    NotchScene.swift         the liquid drop, the pill, how a rest break opens
    RestBreakView.swift      the dim behind a rest break
    RestCard.swift           the rest break's to-do list, reroll, snooze and done
    TypedLine.swift          the typewriter effect
  Settings/
    SettingsView.swift       the pop-up
scripts/release.sh           build, install, publish
packaging/blik.rb.template   the Homebrew cask, filled in by the release script
```

Every animation is a pure function of elapsed time (see `Motion.swift`), so tuning is a matter
of changing numbers: durations in `ReminderKind.swift`, typing cadence in `TypedLine.swift`,
drop size and timing in `NotchScene.swift`.

The project uses Xcode's folder-synchronised groups: any file added under `Blik/` is picked up
automatically.
