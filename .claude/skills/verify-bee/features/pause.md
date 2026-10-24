# Pause

The user stops Bee from keeping the Mac awake for an hour, the rest of today, or the rest of the week. A pause overrides keep-awake, the schedule, and integrations. Resume returns to automatic.

## Sub-features

- `pause-hour` pauses for one hour.
- `pause-today` pauses until local midnight.
- `pause-week` pauses until the end of the calendar week.
- `pause-resume` ends a pause early.

## How to get to it (user POV)

- Click the bee in the menu bar, open `Pause`, choose `1 Hour`, `Rest of Today`, or `Rest of This Week`.
- While paused, choose `Resume` in the same menu.

## Driving it with bee-verify

Preconditions:

- Baseline from the index. To prove the override, something must be keeping Bee awake first: either a running T3 thread with T3 Code on, or `bee-verify menu "Keep Awake" "1 Hour"`.

- **Before.** Run `bee-verify state > build/verify/evidence/pause-before.txt`. The status item reads `Bee is keeping your Mac awake` and a `PreventUserIdleSystemSleep` line exists for our pid.
- **Pause today.** Run `bee-verify menu "Pause" "Rest of Today"`, then `bee-verify state > build/verify/evidence/pause-after.txt`. The headline reads `Paused until tomorrow`, the status item reads `Bee is idle`, assertions show `(none)`, the menu gains `Resume`, and the snapshot `mode` is `{"paused": {"until": <timestamp of next local midnight>}}`.
- **Proof.** Run `bee-verify screenshot paused`. The menu bar capture shows the outlined bee.
- **Resume.** Run `bee-verify menu "Resume"`, then `bee-verify state`. The pre-pause awake state returns with a new assertion line, and the snapshot `mode` is `{"automatic": {}}`.
- **Other lengths.** Repeat with `"1 Hour"` (headline `Paused until <time an hour from now>`) and `"Rest of This Week"` (headline names the first day of next week), resuming after each.

## Gotchas

- `until` is stored as seconds since 2001-01-01 (Swift `Date` default Codable), not Unix time. Convert with `date -r $((<until> + 978307200))`.
- `Resume` only appears while paused or keeping awake. If it's missing, the pause didn't take.
- A pause survives relaunch because it is saved. Cleanup restores the user's saved settings, so a test pause never leaks.
