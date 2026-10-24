# Keep awake

The user forces the Mac to stay awake for a preset time or until they turn it off, regardless of the schedule and integrations.

## Sub-features

- `keep-timed` keeps the Mac awake for 15 Minutes, 30 Minutes, 1 Hour, 2 Hours, 4 Hours, or 8 Hours.
- `keep-indefinite` keeps it awake until turned off.
- `keep-stop` ends a keep-awake and returns to automatic.

## How to get to it (user POV)

- Click the bee in the menu bar, open `Keep Awake`, choose a duration.
- While keeping awake, choose `Stop Keeping Awake` in the same menu.

## Driving it with bee-verify

Preconditions:

- Baseline from the index. Switch T3 Code off first so "awake" can only come from this feature, unless the schedule is active now.

- **Before.** Run `bee-verify state`. The status item reads `Bee is idle` and assertions show `(none)`.
- **Timed.** Run `bee-verify menu "Keep Awake" "15 Minutes"`, then `bee-verify state`. The headline reads `Awake until <time 15 minutes from now>`, the status item reads `Bee is keeping your Mac awake`, a `PreventUserIdleSystemSleep` line exists for our pid, and the snapshot `mode` is `{"keepAwake": {"_0": {"at": {"_0": <timestamp>}}}}` with a timestamp about 900 s ahead.
- **Stop.** Run `bee-verify menu "Stop Keeping Awake"`, then `bee-verify state`. Back to `Bee is idle`, assertions `(none)`, snapshot `mode` is `{"automatic": {}}`.
- **Indefinite.** Run `bee-verify menu "Keep Awake" "Indefinitely"`. The headline reads `Awake until you turn it off` over `Kept awake from this menu` and the snapshot keeps the `never` expiry. Stop it again afterwards.
- **Proof.** `bee-verify screenshot keep-awake` while awake shows the solid bee.

## Gotchas

- Expiry is not instant to observe. A 15-minute run is too long to wait for; trust `make test` (BeeMachineTests) for expiry and verify here that the headline time and stored timestamp are right.
- With T3 Code on and a thread running, `Stop Keeping Awake` still leaves Bee awake (headline `Awake: T3 Code, …`). That is correct precedence, not a failure.
- The exact JSON shape of `mode` comes from Swift's synthesized Codable for `Mode`. Assert the case name (`keepAwake`, `automatic`) and the timestamp, not the nesting.
