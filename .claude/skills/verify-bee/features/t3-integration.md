# T3 Code integration

While any T3 Code thread is running, Bee keeps the Mac awake and says so in the menu and in Settings. The user can switch the integration off.

## Sub-features

- `t3-active` stays awake while a thread runs, with the count in the menu.
- `t3-status` shows live status in Settings → Integrations.
- `t3-toggle` switching the integration off releases the assertion; switching it on restores it after the next check.

## How to get to it (user POV)

- When T3 Code is the reason Bee is awake, the menu headline reads `Awake while T3 Code works` over `<N> thread(s) running…`. Otherwise the menu lists `T3 Code: <status>` below the actions.
- Settings → Integrations has the `T3 Code` switch and a `Status` line.

## Driving it with bee-verify

Preconditions:

- A T3 Code thread is running right now (an agent turn in progress counts; the thread driving this skill usually is one). Check with `~/.t3/bin/t3 thread list --project <path> --json` and look for `"status":"running"`.
- No pause or keep-awake is active, and the schedule is not active now, so T3 is the only reason to be awake.

- **Active.** Run `bee-verify state`. The headline reads `Awake while T3 Code works` over `<N> thread(s) running…` and a `PreventUserIdleSystemSleep` line exists for our pid.
- **Status in Settings.** Run `bee-verify settings Integrations`. The dump shows `AXCheckBox | T3 Code | 1` and a static text with the same running summary.
- **Switch off.** Run `bee-verify toggle "T3 Code"`. It prints `T3 Code = 0`. Then `bee-verify state`: `Bee is idle`, assertions `(none)`, snapshot `enabledIntegrations` is `[]`.
- **Switch on.** Run `bee-verify toggle "T3 Code"` (`T3 Code = 1`), wait 3 s, then `bee-verify state`. Awake again with a new assertion line, snapshot `enabledIntegrations` is `["t3Code"]`.
- **Proof.** Save both `state` reads under `build/verify/evidence/` and run `bee-verify screenshot t3`.

## Gotchas

- Bee polls every 30 s. After a T3 thread starts or stops, wait up to 30 s before reading state. Switching the integration on triggers an immediate check.
- Bee only checks projects with thread activity in the last day, read from `~/.t3/userdata/statev2.sqlite`. A thread in a project idle for over a day is not seen until its project updates.
- If T3 changes its internal database schema, Settings shows the status `Couldn't read T3 projects`. That is a real finding about the integration, not a harness bug.
- The running thread may be in any project, so the summary can read `in 2 projects`.
