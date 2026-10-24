# Developing Bee

## Setup

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

When a thread hits a usage limit and T3 is set to auto-resume it, the thread records the reset time. With **Wait for auto-resume** on, Bee stays awake until two minutes past that time.

The query depends on T3's internal schema and can break when T3 changes it. Bee then shows the integration as unavailable rather than guessing.
