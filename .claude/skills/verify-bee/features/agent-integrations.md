# Claude Code and Codex integrations

While a Claude Code or Codex session the user started is mid-turn or waiting on them, Bee keeps the Mac awake and says so in the menu and in Settings. Sessions T3 Code runs count only under T3 Code. Each integration has its own switch.

## Sub-features

- `agent-claude` stays awake while a user-started Claude Code session is busy or waiting, with the count in the menu.
- `agent-codex` stays awake while a user-started Codex session is mid-turn.
- `agent-t3-excluded` Claude Code and Codex sessions that T3 Code runs show `Nothing running` under those integrations while T3 Code counts them.
- `agent-live` each reacts within about a second of the CLI writing its state.

## How to get to it (user POV)

- When Claude Code or Codex is the only reason Bee is awake, the menu headline reads `Awake while Claude Code works` (or Codex) over `<N> session(s) running…`. Otherwise the menu lists `Claude Code: <status>` and `Codex: <status>` below the actions.
- Settings → Integrations has `Claude Code` and `Codex` switches, each with a `Status` line.

## Driving it with bee-verify

Preconditions: `bee-verify launch --fresh` (all integrations on by default). Run the CLIs from a scratch directory such as `/tmp/bee-probe`, not the repo.

- **Claude Code.** Start `claude -p --permission-mode bypassPermissions "Run 'sleep 30' with Bash, then reply done."` in the background. When running inside a Claude Code session, unset `CLAUDECODE`, `CLAUDE_CODE_*`, and `CLAUDE_PID` first, and set `CLAUDE_CONFIG_DIR` to a profile that has usage left. Poll `bee-verify menu-items` until it shows `Claude Code: 1 session running` (about 3 s including startup). After the process exits, it reads `Nothing running`.
- **Codex.** Start `codex exec --skip-git-repo-check -s workspace-write "Run 'sleep 25', then reply done."` in the background. Expect `Codex: 1 session running`, then `Nothing running` once the turn completes.
- **T3 exclusion.** With a T3 Code thread running on a Claude provider (the thread driving this skill usually is one), `Claude Code` reads `Nothing running` even though `<home>/sessions/<pid>.json` says `busy`. For Codex, start a T3 thread or delegated task on a Codex provider. T3 Code's count goes up by one and `Codex` stays `Nothing running`.
- **Proof.** Save a `state` read for each under `build/verify/evidence/` and run `bee-verify screenshot agents` with Settings open on Integrations.

## Gotchas

- `codex exec` can linger after its turn while a Codex `Stop` hook runs. Bee correctly reads that as idle because the rollout's last turn is complete.
- Claude Code counts `waiting` (a permission prompt) as working, like T3 Code's waiting threads.
- Bee reads its homes when an integration starts, at launch, on wake, and when it's switched on. A new custom home in T3's settings is picked up then.
- A crashed session leaves no file change behind, so it drops out on the 60-second fallback rather than within a second.
