# Lid closed

Power assertions don't stop sleep when a MacBook lid closes. A Settings switch makes Bee also run `pmset -a disablesleep 1` while it keeps the Mac awake, and `0` when it stops or quits. The first time, Bee installs `/etc/sudoers.d/bee` behind one admin password prompt, unless sudo already allows those two commands (Amphetamine's rule counts).

## Sub-features

- `lid-on` switching it on while awake sets `SleepDisabled` to 1.
- `lid-stop` stopping keep-awake sets it back to 0.
- `lid-quit` quitting Bee while it holds the setting sets it back to 0.
- `lid-foreign` Bee never clears a `SleepDisabled` 1 that another app set.

## How to get to it (user POV)

- Settings → General → `Keep awake with the lid closed`.

## Driving it with bee-verify

Preconditions:

- `/usr/bin/sudo -n -l /usr/bin/pmset -a disablesleep 1` exits 0, so switching on shows no password prompt. If it fails, the switch opens a system password dialog that this skill cannot drive.
- `bee-verify state` shows `sleep disabled: 0`. A 1 set by another app makes every step below read 1.

- **On.** Run `bee-verify settings General` (`AXCheckBox | Keep awake with the lid closed | 0`), then `bee-verify toggle "Keep awake with the lid closed"` (`= 1`). The snapshot has `"keepsAwakeWithLidClosed": true`.
- **Awake.** Run `bee-verify menu "Keep Awake" "15 Minutes"`, then `bee-verify state`. It shows `sleep disabled: 1`.
- **Stop.** Run `bee-verify menu "Stop Keeping Awake"`, then `bee-verify state`. It shows `sleep disabled: 0`, unless the schedule or a T3 thread keeps Bee awake.
- **Quit.** Make Bee awake again, confirm `sleep disabled: 1`, run `bee-verify menu "Quit Bee"`, then `pmset -g | grep SleepDisabled`. It reads 0.

## Gotchas

- `bee-verify cleanup` stops Bee with SIGTERM, which skips the quit path. Quit through the menu first when checking `lid-quit`. A Bee killed while holding the setting turns it off on its next launch.
- Pmset runs in the background, so a `state` read right after a click can lag by a moment. Read again before calling it a failure.
- If a run leaves `SleepDisabled` at 1, run `/usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0`.
