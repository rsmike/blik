# Blik

A tiny macOS menu bar app that reminds you to blink, fix your posture and take a proper break
(look away, eye gymnastics, water). No Dock icon, no windows - only the pop-up under the eye icon.

## Run it

1. Open `Blik.xcodeproj` in Xcode 16 or newer.
2. Press Cmd+R. An eye appears in the menu bar.
3. Click it and use the small play buttons to preview each reminder.

Requires macOS 14+. Signing is set to "Sign to Run Locally", so no developer account is needed.

To keep it around: Product > Archive (or build Release), then copy `Blik.app` to `/Applications`
and switch on "Launch at login" in the pop-up.

## How it behaves

- Reminders are full-screen, click-through overlays above everything, including full-screen apps.
  They never take keyboard focus. Only the "skip" pill during a rest break accepts clicks.
- A blink reminder lasts 5 seconds. A posture reminder lasts one second: the same animation,
  played quickly.
- Reminders are held back while you are away from the keyboard (2+ minutes of no input).
  An absence of 5+ minutes, or the Mac sleeping, restarts all intervals.
- A rest break also resets the blink and posture timers.
- "Pause for today" lasts until 5 AM and survives a relaunch.

## Styles

| Style    | What it does                                                                 |
|----------|-------------------------------------------------------------------------------|
| Keyboard | Screen dims, one word is typed in the centre, held, then backspaced away.      |
| Matrix   | Digital rain over the whole screen, a terminal panel decodes the word.         |
| Aurora   | Coloured light breathes in from the screen edges, the word drifts into focus.  |

## Layout

```
Blik/
  BlikApp.swift              entry point, menu bar item
  Core/
    ReminderKind.swift       the three reminders, texts, durations, rest timeline
    AppSettings.swift        persisted settings (UserDefaults)
    Scheduler.swift          when things fire: intervals, pause, idle and sleep handling
    Theme.swift              the three styles
    Motion.swift             easing and timing helpers
  Overlay/
    OverlayController.swift  the overlay windows
    Glyphs.swift             animated eye, posture figure, water glass
  Scenes/
    KeyboardScene.swift, MatrixScene.swift, AuroraScene.swift
    RestBreakView.swift      the long break
    TypedLine.swift          the typewriter effect
    ReminderScene.swift      picks the scene for a reminder
  Settings/
    SettingsView.swift       the pop-up
```

Every animation is a pure function of elapsed time (see `Motion.swift`), so tuning is a matter
of changing numbers: durations in `ReminderKind.swift`, typing cadence in `TypedLine.swift`,
rain density and speed in `MatrixScene.swift`.

The project uses Xcode's folder-synchronised groups: any file added under `Blik/` is picked up
automatically.
