---
name: verify-bee
description: Drive the real Bee macOS menu bar app (keep-awake, pause, schedule, T3 Code integration, Settings window) through Accessibility and prove behavior with power assertions, menu state, saved settings, and screenshots. Use after changing anything under Bee/ to confirm the change works in the running app, not just in unit tests.
---

# Verify Bee

Bee is a menu bar app with no Dock icon and no main window. A user touches two surfaces: the menu under the bee icon in the menu bar, and the Settings window opened from it (its title is the current tab name, and it is the only window Bee has). The effect users care about is a macOS power assertion that keeps the Mac awake, so every proof pairs what the UI says with what `pmset` reports.

All driving goes through one helper, `.claude/skills/verify-bee/scripts/bee-verify`, run from the repo root. It uses `osascript` + System Events, so the terminal running it needs Accessibility permission (System Settings → Privacy & Security → Accessibility). Without it, `doctor` fails the accessibility line.

`make test` covers the domain logic. This skill covers the app. Use both.

## Launch

```sh
.claude/skills/verify-bee/scripts/bee-verify launch           # keep the user's saved settings
.claude/skills/verify-bee/scripts/bee-verify launch --fresh   # start from first-launch defaults
```

It runs `xcodegen generate`, builds Debug into `build/verify/DerivedData` (separate from `make run`'s `build/DerivedData`), and launches that app. Build output goes to `build/verify/state/build.log`; on failure the last 30 lines are printed.

Ready means the bee's menu bar item answers Accessibility and no enabled integration still shows `Checking…` in the menu, so the first T3 check has landed and reads will not flip mid-way. Launch prints `ready: pid <pid>, status item says "<label>"`. The label is `Bee is keeping your Mac awake` or `Bee is idle`.

Isolation. Two Bees cannot run side by side: they share one defaults domain (`com.szymonograbek.Bee`) and both would hold power assertions. So `launch` quits any Bee already running and records its path, backs up the user's defaults to `build/verify/state/defaults-backup.plist`, and `cleanup` restores both. Never drive a Bee that `launch` did not start.

## Doctor

```sh
.claude/skills/verify-bee/scripts/bee-verify doctor
```

Read-only. Checks: our pid is alive, exactly one Bee process exists, it runs the `build/verify` binary, that binary is newer than every `Bee/**/*.swift` (otherwise relaunch to pick up your change), and Accessibility can read the status item. Run it first and whenever a step behaves oddly.

## Drive

| Command | What it does |
|---|---|
| `bee-verify state` | Status item label, the menu's lines, power assertions held by our pid, `SleepDisabled` from `pmset -g`, saved snapshot JSON. The main proof read. |
| `bee-verify menu-items` | Opens the menu, lists items as `[item]` (clickable) or `[text]` (status line), closes it. |
| `bee-verify menu "<item>" ["<subitem>"]` | Clicks a menu path by visible title, e.g. `menu "Keep Awake" "15 Minutes"`, `menu "Pause" "Rest of Today"`, `menu "Resume"`. |
| `bee-verify settings [General\|Schedule\|Integrations]` | Opens Settings on that tab and prints its controls as `role \| name \| value`. |
| `bee-verify toggle "<switch name>"` | Clicks the switch with that name in Settings and prints its new value (`1` on, `0` off). |
| `bee-verify close-settings` | Closes the Settings window. |
| `bee-verify screenshot <name>` | Captures the menu bar icon, plus the Settings window if open, into the evidence dir. |

Stable handles are visible titles: menu titles (`Keep Awake`, `Pause`, `Resume`, `Stop Keeping Awake`, `Settings…`, `Quit Bee`), tab names, and switch names (`Launch at login`, `Keep the display on`, `Keep awake with the lid closed`, `Stop on low battery`, `Ignore while plugged in`, `Keep awake on a schedule`, `T3 Code`, `Claude Code`, `Codex`). Menu text and the status item label come from `Bee/UI/MenuContent.swift` and `Bee/UI/BeeGlyph.swift`; update the feature map when those strings change.

Feature recipes live in [features/README.md](features/README.md).

## Evidence

Artifacts go to `build/verify/evidence/` (override with `BEE_EVIDENCE=<dir>`). Cleanup never touches it.

Proof standards:
- Drive the real user path (menu clicks, Settings switches). Never write to `defaults` to fake a state, and never call the app's internals.
- Capture before and after: `bee-verify state` before the action and after it. Save both with `bee-verify state > "$BEE_EVIDENCE/<feature>-before.txt"`.
- The side effect is the power assertion. A UI label saying "Awake" is not proof without the `pmset` line under `power assertions held by pid`. An idle claim needs `(none)` there.
- Persistence is proven by the `saved snapshot` line, which reads the stored value back, not by the UI.
- A screenshot of the menu bar icon shows the solid bee with lightning-bolt eyes (awake) or the outlined sleeping bee with closed eyes and z's (idle).

## Cleanup

```sh
.claude/skills/verify-bee/scripts/bee-verify cleanup
```

Kills the pid `launch` recorded (never by name), restores the user's defaults from the backup, relaunches the Bee that was running before, and prints where the evidence is. Run it after every run, including failed ones. If `launch` died halfway, `cleanup` is still safe to run.
