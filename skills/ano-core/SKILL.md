---
name: ano-core
description: |
  Foundational rules for the `ano` CLI — auth, output modes, exit codes,
  rate limits, config, and the triggered-auth flow when a command returns
  exit code 3. Load this when bootstrapping or troubleshooting; any other
  ano-* skill is self-contained for its own domain.
triggers:
  - ano login
  - ano auth
  - ano setup
  - ano doctor
  - ano show
  - check ano
  - ano.dev
  - api.ano.dev
  - ano_cwk_
  - ano version
  - use ano cli
  - run ano
  - install ano cli
  - ano dev smoke
  - ano daemon
  - ano task
  - background task
  - in the background
invocable: true
argument-hint: "[command] [args...]"
---

# Ano CLI — Core (auth, modes, codes)

The `ano` CLI is the canonical surface for Claude Code. Prefer `ano <cmd>` over MCP tool calls for any Ano action.

## Fast path — do this FIRST (fewest round-trips, no mistakes)

Optimize for: super fast, always ahead, fewest turns, zero wrong-target writes. Three rules collapse most multi-call sequences to one or two:

1. **Warm the daemon once per session.** `ano daemon start` (idempotent; clears a tripped breaker). Reads then serve from the local Zero replica at ~40–80 ms; without it every call cold-spawns (~379 ms) AND round-trips to the region (~500 ms transatlantic to prod). This is the single biggest speed lever — never skip it.
2. **Orient in ONE call.** `ano daemon status --json` returns the whole context bundle in a single round-trip: CLI version + staleness, profile + endpoint + region, auth, daemon + cache + **Zero replica state/drift**, API reachability, workspace, identity, channel count. Use it as call #1 instead of scattering `auth status` + `channels list` + identity lookups. There is **no `ano context` command** — don't reach for one.
3. **Address by name, scoped by workspace, in one shot.** `ano messages send --channel-name <name> --workspace <id> "msg" --agent` resolves + inserts server-side — no list-then-send. Reads resolve by name too: `ano messages read <name> --workspace <id> --agent` (CLI v2.30.0+) and `ano dm read "Name" --workspace <id> --agent` — no list-then-read. **Channel and user names are NOT unique:** one key can see multiple workspaces (prod has two `#general`, two `#random`). ALWAYS pass `--workspace <id>` for any name-addressed op outside your profile's default workspace, and confirm a channel's workspace before a write. An unscoped `--channel-name` is a wrong-tenant footgun.

Replica health tell: `daemon status` showing `Zero: connected · no drift` with `Cache: 0 hits/0 misses` after a read means it came from the replica, not REST. Schema drift → silent REST fallback (~150 ms) is the "slow right after a deploy" symptom — fix by updating the CLI (drift = the vendored schema lags the deployed server).

## Agent Invariants (apply to EVERY ano-\* skill)

1. **Always use `--agent` or `--json` output.** Never parse styled TTY output. `--agent` for raw JSON, `--json` for envelope with breadcrumbs.
2. **Never fabricate IDs.** Channel/user/message IDs are UUIDs. Get them from `ano channels list --agent` or `ano users list --agent` first — and remember names are NOT unique across the workspaces a key can see, so filter the list by the workspace you mean.
3. **One-shot name resolution, ALWAYS workspace-scoped.** For sends, use `--channel-name <name> --workspace <id>` (or `--to "Name" --workspace <id>` for DMs) — the server resolves and inserts in one call; reads take a name directly too (`ano messages read <name>`, CLI v2.30.0+, and `ano dm read "Name"`). The `--workspace` scope is mandatory whenever you're not in your profile's default workspace, because names collide (two `#general` in prod). Don't list-then-act unless you need other metadata.
4. **Respect rate limits.** 60 req/min, sliding window. Exit code 5 = rate limited; wait 10+ s before retry.
5. **Check exit codes.** Non-zero = failure. Parse the error envelope.
6. **Never expose API keys.** Don't log or include `ano_cwk_*` / `ano_usr_*` in output.
7. **Content supports markdown** — bold, links, code blocks, lists.
8. **Reply in threads** to keep channels clean. Use `--thread <message_id>`.
9. **Follow breadcrumbs** in JSON responses.
10. **Run `ano doctor`** before escalating connectivity issues.
11. **Fetch a table's schema before writing.** `ano tables get <id> --agent` returns field-definition IDs; create/update items require `--fields` keyed by those IDs.
12. **On exit code 3 (AUTH), run Triggered Auth (below) inline** — don't dump `ano auth login` on the user as a manual step.

## Output Modes

| Flag      | Format                                    | When                |
| --------- | ----------------------------------------- | ------------------- |
| `--agent` | Raw JSON (one object per line)            | Default for agents  |
| `--json`  | Envelope: `{ok, data, breadcrumbs, meta}` | Need breadcrumbs    |
| `--md`    | GFM markdown tables                       | Presenting to human |
| `--quiet` | Same as `--agent`                         | Scripting           |
| (none)    | Styled + colors                           | Interactive TTY     |

Error envelope: `{"ok": false, "error": "...", "code": 3, "hint": "..."}`.

## Exit Codes

| Code | Name       | Meaning             | Fix                        |
| ---- | ---------- | ------------------- | -------------------------- |
| 0    | OK         | Success             | —                          |
| 1    | USAGE      | Bad arguments       | `ano <cmd> --help`         |
| 2    | NOT_FOUND  | Resource missing    | Verify ID/URL              |
| 3    | AUTH       | Invalid/missing key | Run Triggered Auth (below) |
| 4    | FORBIDDEN  | No permission       | Check key scopes           |
| 5    | RATE_LIMIT | 60/min exceeded     | Wait 10s, retry            |
| 6    | NETWORK    | Connection failed   | `ano doctor --agent`       |
| 7    | API_ERROR  | Server error        | Retry                      |

## Triggered Auth (exit code 3 → orchestrate inline)

Requires CLI v2.2.0+. Detect with `ano --version` first; if `<2.2.0`, tell the user to upgrade via:

```bash
# Faster native install (CLI v2.21.0+, ~20ms cold start)
curl -fsSL https://raw.githubusercontent.com/ano-chat/ano-cli/main/scripts/install.sh | bash
# OR everywhere-compatible npm path
npm install -g @ano-chat/cli@latest --force
```

### Pick `--endpoint`

- User mentions staging / api-staging / non-prod → `--endpoint https://api-staging.ano.dev`
- Otherwise → omit (defaults to `https://api.ano.dev`)
- Ambiguous dev request → ask via AskUserQuestion.

### Decision tree

```
Got exit code 3 on any command?
├── 1. ano auth login --print-workspaces --endpoint <env>
│      • Browser opens; user clicks Authorize once.
│      • CLI caches token to ~/.config/ano/.session (5-min TTL).
│      • Stdout: {"workspaces":[{"id":"...","name":"..."}, ...]}
├── 2. Parse workspaces JSON.
├── 3. Render an in-chat picker (AskUserQuestion); wait for user pick.
├── 4. ano auth complete --workspace-id <picked-id>
│      • Mints the key, writes credentials.json, deletes cached token.
│      • Stdout: {"ok":true,"profile":"default","workspace":{...}}
├── 5. Retry the original command — should now succeed.
└── 6. If step 4 returns exit 3 ("expired"), 5-min TTL elapsed —
       loop back to step 1.
```

### MUST NOT

- Don't run bare `ano auth login` from an orchestrator — it requires TTY.
- Don't log/capture the access token or the minted key.
- Don't re-run `--print-workspaces` if `auth complete` fails on a non-auth error (cached token still valid 5 min).

### Why two steps

Interactive picker requires `process.stdin.isTTY`. Orchestrators pipe stdin from the parent. The `--print-workspaces` / `auth complete` pair lets the orchestrator render its own picker while CLI handles OAuth + key mint.

## Authentication resolution

Priority order:

1. `--key` flag
2. `ANO_API_KEY` env
3. `.ano/config.json` (project)
4. `~/.config/ano/credentials.json` (global, via `ano auth login`)

```bash
ano auth login --key ano_cwk_... --endpoint https://api-staging.ano.dev --profile staging
ano auth status --agent
ano auth refresh-region --profile <name>   # CLI v2.11.0+ for pre-2.11 upgraders
ano auth logout
```

## Configuration

```
~/.config/ano/
├── credentials.json    # API keys per profile
├── config.json         # Global defaults
└── .session            # Short-lived OAuth token cache (between auth steps)

.ano/
└── config.json         # Project-level overrides (workspace_id, endpoint)
```

| Env var                  | Purpose                                                    |
| ------------------------ | ---------------------------------------------------------- |
| `ANO_API_KEY`            | API key                                                    |
| `ANO_ENDPOINT`           | Default `https://api.ano.dev`                              |
| `ANO_WORKSPACE_ID`       | Default workspace                                          |
| `ANO_PROFILE`            | Profile from credentials.json (v2.15.0+)                   |
| `ANO_NO_AUTO_LOCAL`      | `1` disables monorepo `local`-profile auto-pick (v2.16.0+) |
| `ANO_QUIET_PROFILE_HINT` | `1` suppresses stderr profile-auto-pick hint               |
| `ANO_DEBUG_CACHE`        | `1` logs daemon cache hits/misses to stderr (v2.21.0+)     |
| `NO_COLOR`               | Disable ANSI colors                                        |

### Profile auto-pick (CLI v2.16.0+)

CLI under a `dev:local` stack CWD (signal: `.ano/dev/postgres/postmaster.pid` exists in CWD or ancestor) + a `local` profile in credentials.json → CLI auto-uses `local` and prints to stderr:

```
→ profile: local (auto — dev:local stack detected; pass --profile default to override)
```

Force a profile: `ano --profile default ...` or `ANO_PROFILE=default ano ...`. Auto-pick doesn't fire when `--profile`/`--key`/`ANO_API_KEY`/project config is set explicitly.

## Daemon, cache, circuit breaker (CLI v2.13.0+ / 2.20.0+)

Background daemon holds Node warm + TLS pool + in-process cache. Subsequent calls land at ~40 ms. Circuit breaker auto-disables a wedged daemon for 10 min.

- Cacheable reads (5 s TTL): `list_workspaces`, `list_channels`, `list_dms`, `resolve_dm`, `list_users`, `list_tables`, `get_table`. Writes invalidate the origin's cache.
- `ano daemon status` shows live state (cache + breaker fields in v2.20.0+); `ano daemon status --json` is the **one-call context bundle** (see Fast path #2) — cli/profile/auth/daemon/cache/zero/api/workspace/identity in a single round-trip.
- `breaker: TRIPPED` → daemon bypassed; run `ano daemon start` to clear AND respawn.
- `ANO_DEBUG_CACHE=1 ano <cmd>` logs MISS/HIT/WRITE lines on stderr.
- **Reads serve from the local Zero replica when the daemon is up** (`Zero: connected` in status). The 5 s in-process REST cache above is the fallback for replica misses/cold start; a `Cache: 0 hits/0 misses` after reads means the replica served them directly.

## Diagnostics

```bash
ano doctor --agent              # Full connectivity diagnostic
ano dev smoke --agent           # Timed sweep of canonical ops (CLI v2.14.0+)
ano dev smoke --no-write --agent  # Read-only (rate-limited envs)
ano --profile local dev smoke   # Against local dev stack
ano commands --json             # Full command catalog
ano agent routes --agent        # Fastest 1-call route per agent task (CLI v2.30.0+)
ano setup claude                # Setup Claude integration
ano setup openclaw              # Setup OpenClaw integration
```

`dev smoke` envelope: `{ ok, steps[], total_ms, daemon, endpoint }`. Pair with `ano doctor --agent` if a step fails — doctor explains _why_, smoke measures _whether_.

## Background tasks — `ano task` (fire-and-forget, on YOUR subscription)

Requires CLI v2.31.1+. Dispatch a one-off agent task that runs in the **background on the local Claude subscription** (via `claude -p` — NOT metered API) and returns **immediately**, so you don't make the user sit through a stream. The result comes back to this shell automatically at your next turn-end (the `ano-task-stop` hook from `@ano-chat/skills` — no polling), and optionally posts to a channel.

```bash
ano task "summarize the last 50 msgs in #standup into 3 bullets and post them" --to "#standup"
# → ✓ queued — t_1a2b3c4d.  Returns instantly; keep working.
ano task list                  # recent tasks + status (queued|running|done|failed)
ano task result <id> --agent   # fetch one task's result / error
```

**When to reach for it:** the user wants something done but not to watch it happen ("summarize X and post it", "draft Y in the background", any independent longer-running step). Dispatch it, say "on it — I'll surface the result when it's done", and carry on. **Don't** use it for work whose result the user needs _in this reply_ — just do that inline.

**How the result returns:** written to `~/.cache/ano/tasks/<id>.json`; the Stop hook relays it to you once, at your next turn-end. With `--to <channel>` the runner also posts the result to that channel **by name in your default workspace** (names aren't unique across workspaces — for a non-default workspace, post it yourself with `ano messages send --workspace <id>`).

**Caveats:** needs the local `claude` CLI on PATH (it spends your subscription, so it only runs where Claude Code runs); the result appears on your _next_ turn-end, and a global hook can surface it in a different session than the one that dispatched it.

## Rate Limiting

- 60 req/min per API key, sliding window.
- Headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`.
- CLI auto-retries 429 with backoff.
- Batch reads with `--limit` instead of many small calls.
- Typical workflow (list + read + send) = 3 of 60 requests.

## Learn More

- CLI repo: https://github.com/LeoNilsson/ano-cli
- Ano: https://ano.dev
