<img src="Bee/Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" width="64" height="64" alt="">

# Bee

Bee is a macOS menu bar app that keeps your Mac awake. It works like Amphetamine, with a weekly schedule and a T3 Code integration.

- **Keep Awake** for a preset time (15 minutes to indefinitely).
- **Pause** for an hour, the rest of today, or the rest of the week.
- **Schedule**: weekly windows, 08:00 to 16:00 on workdays by default. Windows can run past midnight.
- **T3 Code**: keeps the Mac awake while any T3 Code thread is running.

A pause beats a manual keep-awake, which beats the schedule, which beats integrations. By default only the Mac stays awake, so the display can still sleep. Settings can keep the display on too.

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

Every 30 seconds Bee asks the `t3` CLI (`~/.t3/bin/t3`, `/opt/homebrew/bin/t3`, or `/usr/local/bin/t3`) for each project's threads with `t3 thread list --project <id> --json`. Any thread whose status is `running` keeps the Mac awake.

The CLI has no command that lists projects, so Bee reads them from T3's local SQLite database (`~/.t3/userdata/statev2.sqlite`, or under `$T3CODE_HOME`) through `/usr/bin/sqlite3 -readonly`. Only projects with thread activity in the last day are checked. This query depends on T3's internal schema and can break when T3 changes it. Bee then shows the integration as unavailable rather than guessing.

Created in [T3 Code](https://t3.codes).
