<img src="Bee/Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" width="64" height="64" alt="">

# Bee

Bee is a macOS menu bar app that keeps your Mac awake. It works like Amphetamine, with a weekly schedule and a T3 Code integration.

- **Keep Awake** for a preset time (15 minutes to indefinitely).
- **Pause** for an hour, the rest of today, or the rest of the week.
- **Schedule**: weekly windows, 08:00 to 16:00 on workdays by default. Windows can run past midnight.
- **T3 Code**: keeps the Mac awake while any T3 Code thread is running.
- **Low battery**: optionally lets the Mac sleep once the battery drops below a limit (20% by default), unless it is plugged in.

A pause beats the low-battery limit, which beats a manual keep-awake, which beats the schedule, which beats integrations. By default only the Mac stays awake, so the display can still sleep. Settings can keep the display on too.

## Lid closed

Power assertions don't stop a MacBook from sleeping when its lid closes. Turn on **Keep awake with the lid closed** in Settings, and while Bee keeps the Mac awake it also runs `pmset -a disablesleep 1`, then `0` once it stops or quits. Bee only turns off a setting it turned on, so it leaves another app's `disablesleep` alone.

`pmset` needs root. The first time you turn the setting on, Bee asks for your password once and installs `/etc/sudoers.d/bee`, which lets your account run only `/usr/bin/pmset -a disablesleep 1` and `/usr/bin/pmset -a disablesleep 0` without a password. If another app (Amphetamine, for example) already allows those commands, Bee uses that and doesn't ask. `brew uninstall` removes the file.

## Install

```sh
brew install --cask szymonograbek/tap/bee
```

Bee is ad-hoc signed, not notarized. The cask removes the quarantine flag so Gatekeeper lets it open.

## Development

Requires Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen), and [SwiftLint](https://github.com/realm/SwiftLint) (`brew install xcodegen swiftlint`).

```sh
make run    # generate the Xcode project, build, and launch Bee
make test   # run the unit tests
make lint   # swiftlint --strict
```

`Bee.xcodeproj` is generated from `project.yml`. Edit `project.yml`, not the project.

## Releasing

Commits follow [Conventional Commits](https://www.conventionalcommits.org) (`feat:`, `fix:`, …); pull requests are checked with commitlint. On every push to `main`, [release-please](https://github.com/googleapis/release-please) keeps a release PR open that bumps `MARKETING_VERSION` in `project.yml` and updates `CHANGELOG.md`. Merging it tags the release, after which the workflow builds `Bee.zip` with `make release`, attaches it to the GitHub release, and updates the cask in [szymonograbek/homebrew-tap](https://github.com/szymonograbek/homebrew-tap) from `packaging/homebrew/bee.rb`.

## T3 Code integration

Bee reads T3's local SQLite database (`~/.t3/userdata/statev2.sqlite`, or under `$T3CODE_HOME`) with one query through `/usr/bin/sqlite3 -readonly`. Any thread with an unfinished run (`queued`, `preparing`, `starting`, `running`, or `waiting` on you) keeps the Mac awake. Bee watches the database and its write-ahead log with FSEvents, so it re-reads within about a second of T3 committing a change. A 60-second timer is the fallback.

When a thread hits a usage limit and T3 is set to auto-resume it, the thread records the reset time. With **Wait for auto-resume** on (Settings → Integrations, on by default), Bee stays awake until two minutes past that time, which gives T3 room to start the resumed run.

The query depends on T3's internal schema and can break when T3 changes it. Bee then shows the integration as unavailable rather than guessing.

Created in [T3 Code](https://t3.codes).
