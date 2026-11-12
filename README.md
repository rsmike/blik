# Blik

A tiny macOS menu bar app that reminds you to blink, fix your posture and take a proper break
(look away, water, stretch, something off-screen). No Dock icon, no windows - only the pop-up under the eye icon.

## Run it

1. Open `Blik.xcodeproj` in Xcode 16 or newer.
2. Press Cmd+R. An eye appears in the menu bar.
3. Click it and use the small play buttons to preview each reminder.

Requires macOS 14+. Signing is set to "Sign to Run Locally", so no developer account is needed.

To keep it around: Product > Archive (or build Release), then copy `Blik.app` to `/Applications`
and switch on "Launch at login" in the pop-up.

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

## Layout

```
Blik/
  BlikApp.swift              entry point, menu bar item
  Core/
    ReminderKind.swift       the three reminders, texts, durations
    AppSettings.swift        persisted settings (UserDefaults)
    Scheduler.swift          when things fire: intervals, pause, snooze, idle and sleep handling
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
    ReminderScene.swift      picks the scene for a reminder
  Settings/
    SettingsView.swift       the pop-up
```

Every animation is a pure function of elapsed time (see `Motion.swift`), so tuning is a matter
of changing numbers: durations in `ReminderKind.swift`, typing cadence in `TypedLine.swift`,
drop size and timing in `NotchScene.swift`.

The project uses Xcode's folder-synchronised groups: any file added under `Blik/` is picked up
automatically.
