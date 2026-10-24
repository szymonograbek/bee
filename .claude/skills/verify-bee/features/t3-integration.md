# T3 Code integration

While any T3 Code thread is running or waiting on the user, Bee keeps the Mac awake and says so in the menu and in Settings. With the auto-resume option on, it also stays awake while a thread that hit a usage limit waits for T3 to resume it. The user can switch the integration and the option off.

## Sub-features

- `t3-active` stays awake while a thread runs, with the count in the menu.
- `t3-status` shows live status in Settings → Integrations.
- `t3-toggle` switching the integration off releases the assertion; switching it on restores it after the next check.
- `t3-live` Bee reacts within about a second of T3 writing to its database.
- `t3-autoresume` the `Wait for auto-resume` switch keeps Bee awake until two minutes past an armed reset time, showing `Auto-resuming at <time>`.

## How to get to it (user POV)

- When T3 Code is the reason Bee is awake, the menu headline reads `Awake while T3 Code works` over `<N> thread(s) running…`. Otherwise the menu lists `T3 Code: <status>` below the actions.
- Settings → Integrations has the `T3 Code` switch, the `Wait for auto-resume` switch, and a `Status` line.

## Driving it with bee-verify

Preconditions:

- A T3 Code thread is running right now (an agent turn in progress counts; the thread driving this skill usually is one). Check with `~/.t3/bin/t3 thread list --project <path> --json` and look for `"status":"running"`.
- For `t3-live` and `t3-autoresume`, use a synthetic T3 home instead of real threads. `launch` passes `T3CODE_HOME` through to the app. Create `$T3CODE_HOME/userdata/statev2.sqlite` in WAL mode with the two tables the query in `Bee/Integrations/T3/T3Integration.swift` reads, and keep one `sqlite3` connection open on it (`sleep 100000 | /usr/bin/sqlite3 statev2.sqlite &`), as the T3 server does.
- No pause or keep-awake is active, and the schedule is not active now, so T3 is the only reason to be awake.

- **Active.** Run `bee-verify state`. The headline reads `Awake while T3 Code works` over `<N> thread(s) running…` and a `PreventUserIdleSystemSleep` line exists for our pid.
- **Status in Settings.** Run `bee-verify settings Integrations`. The dump shows `AXCheckBox | T3 Code | 1` and a static text with the same running summary.
- **Switch off.** Run `bee-verify toggle "T3 Code"`. It prints `T3 Code = 0`. Then `bee-verify state`: `Bee is idle`, assertions `(none)`, snapshot `enabledIntegrations` is `[]`.
- **Switch on.** Run `bee-verify toggle "T3 Code"` (`T3 Code = 1`), wait 3 s, then `bee-verify state`. Awake again with a new assertion line, snapshot `enabledIntegrations` is `["t3Code"]`.
- **Live.** Against the synthetic home, insert a run with status `running` and time until `pmset -g assertions` shows our pid. Set it to `completed` and time until the line is gone. Each should land within about 1 s.
- **Auto-resume.** Set a thread's `payload_json` to `{"limitRecovery":{"resetAt":"<ISO time 10 minutes ahead>","autoResume":true}}`. The menu reads `Auto-resuming at <time>` and the assertion exists. `bee-verify toggle "Wait for auto-resume"` releases it and the snapshot shows `"keepsAwakeForT3AutoResume": false`. A `resetAt` more than two minutes in the past is idle.
- **Proof.** Save both `state` reads under `build/verify/evidence/` and run `bee-verify screenshot t3`.

## Gotchas

- Bee re-reads when `statev2.sqlite` or `statev2.sqlite-wal` changes, coalesced over 1 s, and every 60 s otherwise. Switching the integration or the auto-resume option triggers an immediate check.
- A read-only `sqlite3` cannot open a WAL database whose `-wal` and `-shm` files are missing, which is the state after the last connection closes. So a synthetic home with no open connection, or T3 fully quit, shows `Couldn't read T3 Code's state`.
- The `sqlite3` first on your PATH may not be `/usr/bin/sqlite3` (the Android SDK ships one that behaves differently). Use `/usr/bin/sqlite3` when reproducing what Bee sees.
- If T3 changes its internal database schema, Settings shows the status `Couldn't read T3 Code's state`. That is a real finding about the integration, not a harness bug.
- The running thread may be in any project, so the summary can read `in 2 projects`.
