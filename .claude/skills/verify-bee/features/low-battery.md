# Low battery

With **Stop on low battery** on, Bee stops keeping the Mac awake while the internal battery is below the limit, even during a manual keep-awake, the schedule, or a running integration. Only a pause ranks higher. The menu then reads `Idle on low battery` / `Battery at N%, below your M% limit`. With **Ignore while plugged in** on (the default), the limit only applies on battery power. Bee resumes on its own once the charge rises or the adapter is connected. The section is hidden on Macs without a battery.

## Sub-features

- Limit on/off, a 5–95% slider in steps of 5, and ignore-while-plugged-in.
- Settings persist under `batteryLimit` in the saved snapshot.

## How to get to it (user POV)

Settings… → General → Stop on low battery. The Limit slider and Ignore while plugged in appear once it is on.

## Driving it with bee-verify

1. Read the charge with `pmset -g batt`; the Mac is usually plugged in.
2. `bee-verify settings General`, then `bee-verify toggle "Stop on low battery"` and `bee-verify toggle "Ignore while plugged in"` (turns it off).
3. Raise the slider above the current charge. `bee-verify` has no slider command; increment it through System Events, e.g. `perform action "AXIncrement"` on the window's `AXSlider` (each step is 5%).
4. `bee-verify state`: the menu shows `Idle on low battery`, power assertions are `(none)`, and `sleep disabled: 0` if the lid setting was on.
5. `bee-verify toggle "Ignore while plugged in"` back on: Bee is awake again while plugged in.

## Gotchas

- `bee-verify settings` doesn't list the slider; read its value from the `N%` text next to it.
- Unplugging can't be driven; testing the on-battery path needs the limit above the charge with Ignore while plugged in off.
