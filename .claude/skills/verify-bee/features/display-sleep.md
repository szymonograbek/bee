# Display sleep

By default Bee only keeps the Mac awake and lets the display turn off. A Settings switch keeps the display on too while Bee is awake.

## Sub-features

- `display-on` switching it on changes the assertion to display sleep prevention.
- `display-off` switching it off goes back to system sleep prevention.

## How to get to it (user POV)

- Settings → General → `Also prevent display sleep`.

## Driving it with bee-verify

Preconditions:

- Bee is awake for any reason (T3 thread, schedule, or `bee-verify menu "Keep Awake" "1 Hour"`).

- **Open.** Run `bee-verify settings General`. The dump shows `AXCheckBox | Also prevent display sleep | 0`.
- **On.** Run `bee-verify toggle "Also prevent display sleep"` (`= 1`), then `bee-verify state`. The assertion line for our pid reads `PreventUserIdleDisplaySleep`, and the snapshot has `"preventsDisplaySleep": true`.
- **Off.** Run the toggle again (`= 0`). The assertion reads `PreventUserIdleSystemSleep` and the snapshot has `false`.

## Gotchas

- While Bee is idle there is no assertion either way. Make it awake first or the switch has nothing to show.
- `Launch at login` on the same tab registers whichever Bee.app is running, here the `build/verify` copy. Don't toggle it in a verify run unless that feature is what you are checking, and switch it back.
