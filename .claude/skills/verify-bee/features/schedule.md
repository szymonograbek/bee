# Schedule

The user sets weekly windows during which Bee keeps the Mac awake. The default is Mon–Fri 08:00–16:00. A window whose end is not after its start runs past midnight.

## Sub-features

- `schedule-toggle` switches the whole schedule on or off.
- `schedule-days` picks the weekdays a rule applies to.
- `schedule-times` sets a rule's From and To times.
- `schedule-rules` adds and deletes rules.

## How to get to it (user POV)

- Settings → Schedule. `Keep awake on a schedule` switch, a week preview (one 24-hour track per day, filled where the schedule keeps the Mac awake, with a marker at the current time on today's track), then a `Hours` section with one row per rule: round day chips (M…S, in the system's week order), start and end time pickers joined by `–`, a remove button, and `Add Hours` below the rows.

## Driving it with bee-verify

Preconditions:

- Pick a moment where the outcome is unambiguous: either inside a scheduled window (e.g. a weekday 08:00–16:00 with the default) or outside one. Switch T3 Code off and have no pause or keep-awake, so the schedule is the only reason to be awake.

- **Open.** Run `bee-verify settings Schedule`. The dump shows `AXCheckBox | Keep awake on a schedule | 1`, the preview's hour labels are hidden from Accessibility, then seven unnamed `AXCheckBox` day chips per rule in week order with `1` for selected days, and a `–` text between the time pickers.
- **Inside a window.** Run `bee-verify state`. The headline reads `Awake until 16:00` over `Following your schedule` and an assertion line exists.
- **Outside a window.** The headline reads `Idle` over `Schedule starts <day> 08:00` and assertions show `(none)`.
- **Switch off.** Run `bee-verify toggle "Keep awake on a schedule"` (`= 0`). Inside a window, Bee goes idle with `(none)`. The snapshot has `"isEnabled": false`. Switch it back on.
- **Proof.** Run `bee-verify screenshot schedule` with Settings open on Schedule.

## Gotchas

- The day chips carry the full weekday as their accessibility description, not their name, and the remove button and `Add Hours` expose no name either, so `toggle` cannot address a day by name and `schedule-days`, `schedule-times`, and `schedule-rules` cannot be driven by this harness yet. Report them as not driven. The fix is matching on description in `bee-verify`, or naming the controls in `Bee/UI/Settings/ScheduleSettingsView.swift`; until then rely on `make test` (ScheduleTests) for the window logic.
- Saturdays and Sundays are outside the default schedule. On a weekend the "inside a window" step cannot run without editing the rule, which the harness cannot do yet.
- Times are local. The snapshot stores `{"hour": 8, "minute": 0}` with no time zone.
