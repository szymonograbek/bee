# Bee verification map

This directory is the maintained source for verifying Bee's user-facing behavior. Read this index before driving the app, then use the matching feature file as the recipe. `bee-verify` below means `.claude/skills/verify-bee/scripts/bee-verify`, run from the repo root.

## Baseline preconditions

- `bee-verify launch` reported `ready`, and `bee-verify doctor` passes every line.
- Know whether a T3 Code thread is running: `bee-verify state` shows `T3 Code: N threads running` in the menu. A running thread keeps Bee awake on its own. For a deterministic baseline, switch it off with `bee-verify settings Integrations` then `bee-verify toggle "T3 Code"`; cleanup restores the user's setting.
- Know whether the schedule is active now (default Mon–Fri 08:00–16:00, local time). An active schedule also keeps Bee awake.

## Driving conventions

- Address controls by visible title. Menu items by title, tabs by name, switches by name.
- One action per command. Read `bee-verify state` after each.
- Undo every mutation inside the run (resume after a pause, switch a toggle back) or rely on `cleanup`, which restores the user's saved settings.

## Proof and skip reporting

- Pair the action with the resulting state: a `state` read before and after, saved under `build/verify/evidence/`.
- Awake proof is a `PreventUserIdleSystemSleep` or `PreventUserIdleDisplaySleep` line for our pid. Idle proof is `(none)`.
- Persistence proof is the `saved snapshot` JSON.
- If a path cannot be driven (see each file's Gotchas), report the attempted command and why. Do not report it as verified through another path.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph of user-visible behavior, then exactly four H2 sections: `Sub-features`, `How to get to it (user POV)`, `Driving it with bee-verify`, `Gotchas`.

## Features

- [Keep awake](./keep-awake.md) covers timed and indefinite keep-awake and stopping it.
- [Pause](./pause.md) covers pausing for an hour, today, or this week, and resuming.
- [T3 Code integration](./t3-integration.md) covers staying awake while a T3 thread runs and switching the integration off.
- [Display sleep](./display-sleep.md) covers the option to keep the screen on too.
- [Lid closed](./lid-closed.md) covers staying awake with the MacBook lid closed through `pmset disablesleep`.
- [Schedule](./schedule.md) covers the weekly schedule editor and its effect.
- [Low battery](./low-battery.md) covers letting the Mac sleep below a battery limit, and ignoring it while plugged in.
