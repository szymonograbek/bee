<p align="center">
  <img src="Bee/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="Bee">
</p>

# Bee

Bee is a macOS menu bar app that keeps your Mac awake. It works like Amphetamine, with a weekly schedule and a T3 Code integration.

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
- **Low battery**: optionally lets the Mac sleep once the battery drops below a limit (20% by default), unless it is plugged in.

A pause beats the low-battery limit, which beats a manual keep-awake, which beats the schedule, which beats integrations. By default only the Mac stays awake, so the display can still sleep. Settings can keep the display on too.

## Lid closed

Power assertions don't stop a MacBook from sleeping when its lid closes. Turn on **Keep awake with the lid closed** in Settings, and while Bee keeps the Mac awake it also runs `pmset -a disablesleep 1`, then `0` once it stops or quits. Bee only turns off a setting it turned on, so it leaves another app's `disablesleep` alone.

`pmset` needs root. The first time you turn the setting on, Bee asks for your password once and installs `/etc/sudoers.d/bee`, which lets your account run only `/usr/bin/pmset -a disablesleep 1` and `/usr/bin/pmset -a disablesleep 0` without a password. If another app (Amphetamine, for example) already allows those commands, Bee uses that and doesn't ask. `brew uninstall` removes the file.

## T3 Code

Bee keeps the Mac awake while any T3 Code thread is queued, running, or waiting on you. It only reads T3's local database, read-only, and notices changes within about a second.

When a thread hits a usage limit and T3 is set to auto-resume it, **Wait for auto-resume** (Settings → Integrations, on by default) keeps the Mac awake until two minutes past the reset time, so T3 can start the resumed run.

If a T3 Code update changes its internal database, Bee shows the integration as unavailable instead of guessing.

## Contributing

See [DEVELOPERS.md](DEVELOPERS.md).

Created in [T3 Code](https://t3.codes).
