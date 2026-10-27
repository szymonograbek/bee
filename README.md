<p align="center">
  <img src="Bee/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="Bee">
</p>

# Bee

Bee is a macOS menu bar app that keeps your Mac awake. It works like Amphetamine, with a weekly schedule and T3 Code, Claude Code, and Codex integrations.

## Install

```sh
brew install --cask szymonograbek/tap/bee
```

Bee is ad-hoc signed, not notarized. The cask removes the quarantine flag so Gatekeeper lets it open.

## Features

- **Keep Awake** for a preset time (15 minutes to indefinitely).
- **Pause** for an hour, the rest of today, or the rest of the week.
- **Schedule**: weekly windows, 08:00 to 16:00 on workdays by default. Windows can run past midnight.
- **T3 Code**: keeps the Mac awake while any T3 Code thread is running.
- **Claude Code** and **Codex**: keep the Mac awake while a session you started is working or waiting on you.
- **Bluetooth with the lid closed**: optionally turns Bluetooth off, or disconnects devices you choose, while the lid is closed, so headphones don't stay connected to a Mac in your bag.
- **Low battery**: optionally lets the Mac sleep once the battery drops below a limit (20% by default), unless it is plugged in.

A pause beats the low-battery limit, which beats a manual keep-awake, which beats the schedule, which beats integrations. By default only the Mac stays awake, so the display can still sleep. Settings can keep the display on too.

## Lid closed

Power assertions don't stop a MacBook from sleeping when its lid closes. Turn on **Keep awake with the lid closed** in Settings, and while Bee keeps the Mac awake it also runs `pmset -a disablesleep 1`, then `0` once it stops or quits. Bee only turns off a setting it turned on, so it leaves another app's `disablesleep` alone.

`pmset` needs root. The first time you turn on a setting that needs it, Bee asks for your password once and installs `/etc/sudoers.d/bee`, which lets your account run only these without a password:

- `/usr/bin/pmset -a disablesleep 1` and `/usr/bin/pmset -a disablesleep 0`
- `/usr/bin/pmset schedule wake …` and `/usr/bin/pmset schedule cancel wake …`, for **Sleep until it resumes**

If another app (Amphetamine, for example) already allows the `disablesleep` commands, Bee uses that and doesn't ask. `brew uninstall` removes the file.

**Bluetooth with the lid closed** (Settings → General) has two modes:

- **Turn off Bluetooth** switches the radio off while the lid is closed, and back on when you open it, the way [Bluesnooze](https://github.com/odlp/bluesnooze) does on sleep. Bee only turns back on a radio it turned off.
- **Disconnect chosen devices** disconnects the paired devices you tick, and reconnects the ones it disconnected when you open the lid. It needs Bluetooth access, which Bee asks for when you pick it. AirPods may still switch back to the Mac on their own if it plays a sound.

With an external display connected, Bee treats the Mac as a workstation and leaves Bluetooth alone.

## T3 Code

Bee keeps the Mac awake while any T3 Code thread is queued, running, or waiting on you. It only reads T3's local database, read-only, and notices changes within about a second.

Bee keeps the Mac awake for at most 2 hours while a thread waits on you. By then you've likely left, and answering wakes the Mac anyway.

When a thread hits a usage limit and T3 is set to auto-resume it, **Wait for auto-resume** (Settings → Integrations, on by default) keeps the Mac awake until two minutes past the reset time, so T3 can start the resumed run.

With **Sleep until it resumes** also on, Bee lets the Mac sleep through that wait once you're away, and schedules a wake a minute before the reset. You're away after 5 minutes without keyboard or mouse input, or as soon as the lid is closed with no external display. Your apps stay as they were, and T3 resumes the thread after the wake.

If a T3 Code update changes its internal database, Bee shows the integration as unavailable instead of guessing.

## Claude Code and Codex

Bee keeps the Mac awake while a Claude Code or Codex session you started, in a terminal or another app, is mid-turn or waiting on you. A Claude Code session waiting on you counts for at most 2 hours. Codex doesn't record when it waits on you, so it counts until it stops. It needs no hooks or setup: it reads the state both CLIs already keep on disk and notices changes within about a second.

Sessions that T3 Code runs are T3 threads, so only the T3 Code integration counts them. A `claude` you type into a terminal inside T3 Code still counts as Claude Code.

Bee looks in `~/.claude` and `~/.codex` (or `$CLAUDE_CONFIG_DIR` and `$CODEX_HOME` when Bee is launched with them), plus any custom home set for a provider in T3 Code's settings.

## Contributing

See [DEVELOPERS.md](DEVELOPERS.md).

Created in [T3 Code](https://t3.codes).
