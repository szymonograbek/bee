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

## Claude Code and Codex integrations

Neither needs hooks. Both read state the CLIs keep anyway, re-read on FSEvents, and fall back to the same 60-second timer. Homes come from the default (`~/.claude`, `~/.codex`), the override variable (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`), and every `homePath` T3 Code's `settings.json` sets for a `claudeAgent` or `codex` provider.

- **Claude Code.** Each process keeps `<home>/sessions/<pid>.json` with a `status` of `busy`, `waiting`, or `idle`, and deletes it on a clean exit. Bee counts files that aren't `idle` whose pid is alive with the recorded `procStart`, which rules out a crashed session's reused pid. It skips a session whose direct parent runs from the T3 Code app bundle. Only the direct parent counts, so a `claude` started from T3's terminal is still the user's.
- **Codex.** Codex keeps a session's rollout (`<home>/sessions/YYYY/MM/DD/rollout-*.jsonl`) open while the session is loaded. Bee lists the rollouts open in running `codex` processes, so a crashed session drops out on its own. A session is working when its latest `task_started` has no later `task_complete` or `turn_aborted`. It skips rollouts whose `session_meta.originator` is `T3 Code`, which also covers a shared Codex daemon that T3 doesn't parent.

Both formats are internal to the CLIs. If one changes, the session stops counting.
