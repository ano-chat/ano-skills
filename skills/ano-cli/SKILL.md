---
name: ano-cli
description: |
  CLI for Ano team communication. Channels, messages, DMs, users, workspaces,
  tables, search, real-time streaming, and agent setup. Use for ANY Ano action.
triggers:
  - send a message
  - send message to
  - post in channel
  - reply in thread
  - read messages
  - read channel
  - search messages
  - find messages
  - send dm
  - send direct message
  - send group dm
  - dm multiple people
  - dm a group
  - message a group
  - share a file
  - attach file
  - send file
  - send screenshot
  - upload file
  - upload screenshot
  - share screenshot
  - send screenshot to channel
  - list channels
  - show channels
  - list users
  - list members
  - list workspaces
  - list tables
  - show tables
  - query table
  - read table
  - create table
  - add row
  - add table item
  - update row
  - update table item
  - comment on table item
  - list automations
  - create automation
  - new automation
  - edit automation
  - pause automation
  - resume automation
  - delete automation
  - run automation
  - automation runs
  - webhook setup
  - connect to linear
  - connect to gmail
  - connect to notion
  - connect to posthog
  - connect to hubspot
  - authorize service
  - set up integration
  - integrations connect
  - ano login
  - ano auth
  - ano connect
  - ano setup
  - ano doctor
  - ano show
  - check ano
  - notify team
  - notify channel
  - update the team
  - post an update
  - archive channel
  - archive a channel
  - add to channel
  - add member to channel
  - remove from channel
  - kick from channel
  - create coworker
  - update coworker
  - edit coworker
  - change coworker
  - pause coworker
  - resume coworker
  - disable coworker
  - enable coworker
  - create teammate
  - new coworker
  - new ai teammate
  - add ai coworker
  - external coworker
  - managed coworker
  - test coworker webhook
  - invite teammate
  - invite member
  - send invite
  - add to workspace
  - add member to workspace
  - remove from workspace
  - kick from workspace
  - workspace member
  - promote to member
  - set dnd
  - do not disturb
  - dnd hours
  - snooze notifications
  - quiet hours
  - mute notifications
  - block notifications
  - clear dnd
  - notification preferences
  - notification settings
  - notification level
  - mentions only
  - email notifications
  - mute email
  - email digest
  - desktop push
  - mobile push
  - ano.dev
  - api.ano.dev
  - ano_cwk_
invocable: true
argument-hint: "[command] [args...]"
---

# Ano CLI — Agent Skill

CLI for Ano team communication. Read/send messages, list channels and members,
read and write tables, build automations, search conversations, stream
real-time events, and manage agent integrations.

**The CLI is the canonical surface for Claude Code.** When a user asks you to
do something in Ano, prefer `ano <command>` over MCP tool calls. MCP is a
fallback for environments without the CLI installed.

## Agent Invariants

1. **Always use `--agent` or `--json` output.** Never parse styled TTY output.
   Use `--agent` for raw JSON; `--json` for envelope with breadcrumbs.
2. **Never fabricate IDs.** Channel/user/message IDs are UUIDs. Get them from
   `ano channels list --agent` or `ano users list --agent` first.
3. **Prefer one-shot name resolution over list-then-act.** For sends, use
   `--channel-name <name>` (CLI ≥2.12.0): the server resolves and inserts in
   one call. Same for DMs: pass `--to "Leo"` directly to `ano dm send`. **Do
   NOT** call `ano channels list` / `ano users list` first if you only need
   the ID for an immediate send — that doubles wall time. List/lookup is
   only correct when you need other channel/user metadata before deciding.
   If a `<ano_payload>` provided IDs, use them directly — don't look up.
4. **Respect rate limits.** 60 requests/minute. Exit code 5 = rate limited.
   Wait 10+ seconds before retrying.
5. **Check exit codes.** Non-zero = failure. Parse the error envelope.
6. **Never expose API keys.** Don't log or include `ano_cwk_*` or `ano_usr_*` keys in output.
7. **Content supports markdown.** Bold, links, code blocks, lists all work.
8. **Reply in threads** to keep channels clean. Use `--thread <message_id>`.
9. **Follow breadcrumbs.** JSON responses include suggested next commands.
10. **Run `ano doctor`** before escalating connectivity issues.
11. **Fetch a table's schema before writing to it.** `ano tables get <table-id> --agent`
    returns the field-definition IDs. `create-item` / `update-item` require the
    `--fields` JSON to be keyed by field-definition ID, not by the human-readable
    field name.
12. **On exit code 3 (AUTH), run the Triggered Auth flow before surfacing the error.**
    Don't dump "run `ano auth login`" on the user as a manual step — orchestrate it
    inline using `--print-workspaces` + `auth complete`. See "Triggered Auth" below.

## Output Modes

| Flag      | Format                                    | When to use               |
| --------- | ----------------------------------------- | ------------------------- |
| `--agent` | Raw JSON (one object per line)            | Default for agents        |
| `--json`  | Envelope: `{ok, data, breadcrumbs, meta}` | When you need breadcrumbs |
| `--md`    | GFM markdown tables                       | Presenting to humans      |
| `--quiet` | Same as `--agent`                         | Scripting                 |
| (none)    | Styled with colors                        | Interactive TTY           |

### JSON envelope (`--json`)

```json
{
  "ok": true,
  "data": [...],
  "breadcrumbs": [
    {"action": "read_messages", "cmd": "ano messages read --channel <id>", "description": "Read messages"}
  ],
  "meta": {"timestamp": "...", "version": "2.4.0"}
}
```

### Error output

```json
{
  "ok": false,
  "error": "Invalid or expired API key",
  "code": 3,
  "hint": "Run \"ano auth login\" or pass --key"
}
```

## CLI Introspection

```bash
ano channels list --help --agent    # Structured JSON for one command
ano commands --json                 # Full command catalog
```

`--help --agent` returns:

```json
{
  "command": "ano channels list",
  "path": ["ano", "channels", "list"],
  "description": "List channels in the workspace",
  "args": [],
  "flags": [],
  "subcommands": []
}
```

## Quick Reference

| Task                                                          | Command                                                                                                                            |
| ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **Auth**                                                      |                                                                                                                                    |
| Save API key                                                  | `ano auth login --key <key>`                                                                                                       |
| Browser login                                                 | `ano auth login --workspace-id <id>` (requires CLI v2.1.0+)                                                                        |
| Triggered auth (orchestrators) — step 1                       | `ano auth login --print-workspaces` (CLI v2.2.0+)                                                                                  |
| Triggered auth — step 2                                       | `ano auth complete --workspace-id <id>` (CLI v2.2.0+)                                                                              |
| Check auth                                                    | `ano auth status --agent`                                                                                                          |
| Refresh regional endpoint (pre-2.11 upgraders)                | `ano auth refresh-region [--profile <name>]` (CLI v2.11.0+)                                                                        |
| Remove credentials                                            | `ano auth logout`                                                                                                                  |
| **Read**                                                      |                                                                                                                                    |
| List channels                                                 | `ano channels list --agent`                                                                                                        |
| Create channel                                                | `ano channels create <name> [--private] [--topic ...] [--members u1,u2]`                                                           |
| List users                                                    | `ano users list --agent`                                                                                                           |
| List workspaces                                               | `ano workspaces list --agent`                                                                                                      |
| Read messages                                                 | `ano messages read --channel <id> --agent`                                                                                         |
| Read (limited)                                                | `ano messages read --channel <id> --limit 10 --agent`                                                                              |
| Search messages                                               | `ano messages search "query" --agent`                                                                                              |
| Search (limited)                                              | `ano messages search "query" --limit 5 --agent`                                                                                    |
| Show URL content                                              | `ano show <url> --agent`                                                                                                           |
| **Write**                                                     |                                                                                                                                    |
| Send message (preferred)                                      | `ano messages send "text" --channel-name engineering --agent`                                                                      |
| Send message (by ID)                                          | `ano messages send "text" --channel <id> --agent`                                                                                  |
| Reply in thread                                               | `ano messages send "text" --channel <id> --thread <msg_id> --agent`                                                                |
| Send with @mention                                            | `ano messages send "text" --channel-name engineering --mention <user_id> --agent`                                                  |
| Send DM (by name)                                             | `ano dm send "text" --to "Name" --agent`                                                                                           |
| Send DM (by email)                                            | `ano dm send "text" --email user@co.com --agent`                                                                                   |
| Send DM (by ID)                                               | `ano dm send "text" --user-id <id> --agent`                                                                                        |
| Send group DM (by names)                                      | `ano dm send "text" --to "Alice" --to "Bob" --agent` (CLI v2.17.0+)                                                                |
| Send group DM (comma form)                                    | `ano dm send "text" --to "Alice,Bob,Carol" --agent`                                                                                |
| Send group DM (mixed name + id)                               | `ano dm send "text" --to "Alice" --user-id <id> --agent`                                                                           |
| Send with file attachment                                     | `ano messages send "see screenshot" --channel-name engineering --file ./bug.png --agent` (CLI v2.18.0+)                            |
| Send screenshot only (empty caption)                          | `ano messages send "" --channel-name design --file ./shot.png --agent`                                                             |
| Send multiple files                                           | `ano messages send "logs" -c <id> --file ./out.txt --file ./err.txt --agent`                                                       |
| DM with file attachment                                       | `ano dm send "fyi" --to "Alice" --file ./report.pdf --agent`                                                                       |
| **Tables**                                                    |                                                                                                                                    |
| List tables                                                   | `ano tables list --agent`                                                                                                          |
| Get table + schema                                            | `ano tables get <table-id> --agent`                                                                                                |
| Query items                                                   | `ano tables query <table-id> --agent`                                                                                              |
| Query (filtered)                                              | `ano tables query <table-id> --filter '<json-array>' --agent`                                                                      |
| Query (sorted)                                                | `ano tables query <table-id> --sort '<json>' --agent`                                                                              |
| Create table                                                  | `ano tables create "<name>" --agent`                                                                                               |
| Create item                                                   | `ano tables create-item --table <id> --fields '<json>' --agent`                                                                    |
| Update item                                                   | `ano tables update-item <item-id> --fields '<json>' --agent`                                                                       |
| Archive item                                                  | `ano tables update-item <item-id> --archive --agent`                                                                               |
| Comment on item                                               | `ano tables comment <item-id> "body" --agent`                                                                                      |
| **Automations (build-before-talk — DEFAULT for Claude Code)** |                                                                                                                                    |
| Submit a compiled plan                                        | `ano automation create-compiled --file plan.json --agent`                                                                          |
| Submit from stdin                                             | `cat plan.json \| ano automation create-compiled --file - --agent`                                                                 |
| Validate offline first                                        | `ano automation validate --file plan.json --agent`                                                                                 |
| **Automations (granular)**                                    |                                                                                                                                    |
| Compile only (no save)                                        | `ano automation compile "prompt" --agent`                                                                                          |
| Create from prompt (server LLM, slow)                         | `ano automation create "prompt" --agent`                                                                                           |
| ⚠ Interactive (USER-only, NOT YOU)                            | `ano new automation`, `ano edit automation` — see warning in Decision Trees                                                        |
| Update                                                        | `ano automation update <slug-or-id> --name "..." --agent`                                                                          |
| List                                                          | `ano automation list --agent` (returns `slug` + `id` per row)                                                                      |
| Recent runs                                                   | `ano automation runs <slug-or-id> --agent`                                                                                         |
| Test (dry-run)                                                | `ano automation run <slug-or-id> --agent`                                                                                          |
| Run for real                                                  | `ano automation run <slug-or-id> --no-dry-run --agent`                                                                             |
| Pause                                                         | `ano automation pause <slug-or-id>`                                                                                                |
| Resume                                                        | `ano automation resume <slug-or-id>`                                                                                               |
| Delete                                                        | `ano automation delete <slug-or-id>`                                                                                               |
| Webhook setup/rotate                                          | `ano automation webhook-setup <slug-or-id> --agent`                                                                                |
| Activate webhook (flip stub → live)                           | `ano automation activate <slug-or-id> --agent` (CLI v2.8.2+)                                                                       |
| Validate compiled plan (offline)                              | `ano automation validate --file plan.json --agent`                                                                                 |
| **Channels (admin)**                                          |                                                                                                                                    |
| Archive channel                                               | `ano channels archive <channel-id> --agent`                                                                                        |
| Add member to channel                                         | `ano channels member-add <channel-id> --user <user-id> --agent`                                                                    |
| Remove member from channel                                    | `ano channels member-remove <channel-id> --user <user-id> --agent`                                                                 |
| **Coworkers (AI teammates)**                                  |                                                                                                                                    |
| Create managed coworker                                       | `ano coworker create "Display Name" --role-title "Role" --agent`                                                                   |
| Create external coworker                                      | `ano coworker create "Display Name" --role-title "Role" --external --webhook-url <url> --agent`                                    |
| Update coworker                                               | `ano coworker update <coworker-id> [--display-name …] [--role-title …] [--custom-instructions …] [--enabled true/false] … --agent` |
| Test outbound webhook                                         | `ano coworker webhook-test <coworker-id> --agent`                                                                                  |
| **Notifications & DND**                                       |                                                                                                                                    |
| Set DND window                                                | `ano dnd set --start 22:00 --end 07:00 --agent`                                                                                    |
| Clear DND                                                     | `ano dnd set --clear --agent`                                                                                                      |
| Update notification prefs                                     | `ano notifications prefs-set --global-level mentions_dms --agent`                                                                  |
| Toggle email notifications                                    | `ano notifications prefs-set --no-email --agent`                                                                                   |
| **Workspaces**                                                |                                                                                                                                    |
| List workspaces                                               | `ano workspaces list --agent`                                                                                                      |
| Set active workspace                                          | `ano workspaces use <workspace-id>`                                                                                                |
| Add member (auto-joins public channels)                       | `ano workspaces member-add <workspace-id> <user-id> --agent`                                                                       |
| Remove member (soft-delete, reversible)                       | `ano workspaces member-remove <workspace-id> <user-id> --agent`                                                                    |
| **Invites**                                                   |                                                                                                                                    |
| Invite teammate                                               | `ano invite <email> [--expires-hours N]`                                                                                           |
| Open invite (no email)                                        | `ano invite [--expires-hours N]`                                                                                                   |
| **Integrations (third-party OAuth)**                          |                                                                                                                                    |
| Authorize a service (Linear, Gmail, Notion, PostHog, etc.)    | `ano integrations connect <app> --agent` (CLI v2.9.0+)                                                                             |
| **Real-time**                                                 |                                                                                                                                    |
| Start SSE bridge                                              | `ano connect`                                                                                                                      |
| Bridge + agent mode                                           | `ano connect --openclaw <url>`                                                                                                     |
| Bridge + health                                               | `ano connect --health-port 8080`                                                                                                   |
| Install service                                               | `ano connect install-service`                                                                                                      |
| Remove service                                                | `ano connect uninstall-service --service-name <name-or-hash>`                                                                      |
| **Diagnostics**                                               |                                                                                                                                    |
| Full diagnostics                                              | `ano doctor --agent`                                                                                                               |
| Smoke test (timed sweep of canonical ops)                     | `ano dev smoke --agent` (CLI v2.14.0+)                                                                                             |
| Smoke test, read-only                                         | `ano dev smoke --no-write --agent`                                                                                                 |
| Daemon status (warm process + cache stats + breaker state)    | `ano daemon status` (CLI v2.13.0+; cache + breaker fields added in v2.20.0+)                                                       |
| Daemon start (or clear circuit breaker)                       | `ano daemon start` (CLI v2.20.0+ clears the breaker when invoked)                                                                  |
| Debug-log cache hits/misses to stderr                         | `ANO_DEBUG_CACHE=1 ano <cmd>` (CLI v2.21.0+)                                                                                       |
| Command catalog                                               | `ano commands --json`                                                                                                              |
| Setup Claude                                                  | `ano setup claude`                                                                                                                 |
| Setup OpenClaw                                                | `ano setup openclaw`                                                                                                               |

## Triggered Auth (when CLI is unauthenticated)

If `ano <command> --agent` returns exit code **3 (AUTH)** — DO NOT dump the
error and the `ano auth login` hint on the user. Run the triggered-auth flow
inline. The user gets ONE browser click + one in-chat workspace pick, instead
of a context switch and a manual setup detour.

**Requires CLI v2.2.0+.** If the installed CLI is older, fall back to telling
the user to upgrade (`npm install -g @ano-chat/cli@latest --force`) before
retrying.

### Detect the installed version first

Before invoking the new flags, run `ano --version`. The output is a single
semver line (e.g. `2.2.0`). Compare:

- Major < 2 OR (major == 2 AND minor < 2) → CLI is too old. Tell the user
  to upgrade. Two paths: `npm install -g @ano-chat/cli@latest --force`
  (works everywhere Node 20+ runs), OR the faster native binary path
  (CLI v2.21.0+):
  ```bash
  curl -fsSL https://raw.githubusercontent.com/ano-chat/ano-cli/main/scripts/install.sh | bash
  ```
  Don't try to invoke the new flags before upgrading — they don't
  exist and the CLI errors with "unknown option."
- Major == 2 AND minor >= 2 → triggered auth is supported.
- Major >= 3 → assume forward-compatibility unless you've seen a breaking
  change in the changelog.

If the CLI binary is missing entirely (`ano: command not found`), tell
the user to install it first. Same two install paths as above —
recommend the native script for speed (no Node required, ~20 ms
cold start vs ~150 ms via Node):

```bash
curl -fsSL https://raw.githubusercontent.com/ano-chat/ano-cli/main/scripts/install.sh | bash
```

The npm path (`npm install -g @ano-chat/cli`) is the everywhere-
compatible alternative.

### Pick the right --endpoint

The `--print-workspaces` and `auth complete` commands accept `--endpoint`.
Choose:

- If the user mentions **staging**, **api-staging**, **api-staging.ano.dev**,
  **ano-staging**, or anything indicating a non-prod environment → use
  `--endpoint https://api-staging.ano.dev`.
- Otherwise → omit the flag (CLI defaults to `https://api.ano.dev`, which
  is what real users want).
- When unsure (e.g. the user is a developer and the request is ambiguous
  between envs), ask via AskUserQuestion: "Are you connecting to production
  or staging?"

### Decision tree

```
Got exit code 3 (AUTH) on any command?
├── 1. ano auth login --print-workspaces --endpoint <env>
│      • Browser opens; user clicks Authorize once.
│      • CLI caches the access token to ~/.config/ano/.session (5-min TTL).
│      • CLI prints {"workspaces":[{"id":"...","name":"..."}, ...]} to stdout.
│      • CLI exits without minting a key.
├── 2. Parse the workspaces JSON from stdout.
├── 3. Render an in-chat picker (e.g. AskUserQuestion in Claude Code) with
│      one option per workspace name. Wait for the user's pick.
├── 4. ano auth complete --workspace-id <picked-id>
│      • CLI reads the cached token, mints the key, writes credentials.json,
│        deletes the cached token.
│      • Stdout: {"ok":true,"profile":"default","workspace":{...}}
├── 5. Retry the original command. It should now succeed.
└── 6. If step 4 returns exit code 3 ("expired"), the user took >5 min;
       loop back to step 1 to start a fresh OAuth.
```

### What the orchestrator MUST do

- Pick `--endpoint` per the heuristic in "Pick the right --endpoint" above.
- Treat `--print-workspaces` stdout as the canonical workspace list. Don't
  hard-code IDs.
- Treat `auth complete --workspace-id <id>` stdout as machine-readable
  (it's a single JSON line). Parse `{ok, profile, workspace}`.
- Surface the original task as soon as auth succeeds — don't make the user
  re-issue the request.

### What the orchestrator MUST NOT do

- Don't run `ano auth login` (no flags) — it requires a TTY for the workspace
  picker, which orchestrators don't have. Use the `--print-workspaces` /
  `auth complete` pair instead.
- Don't capture or log the access token or the minted CLI key. Both are
  short-lived/sensitive.
- Don't re-run `--print-workspaces` if `auth complete` fails on a NON-auth
  error (network blip during mint, invalid workspace id) — the cached token
  is still valid for 5 minutes; just retry `auth complete` or ask the user
  to verify the workspace pick. **BUT** if `auth complete` returns exit
  code 3 (AUTH) or its error mentions "expired" / "no cached login session",
  the 5-minute TTL has elapsed and you MUST re-run `--print-workspaces` to
  start a fresh OAuth round before retrying.

### Why two steps

The CLI's interactive workspace picker requires `process.stdin.isTTY`.
Claude Code's bash bridge (and most orchestrators) pipe stdin from the
parent process — not a TTY. The `--print-workspaces` / `auth complete`
pair lets the orchestrator render its OWN picker while the CLI handles
OAuth and key minting.

## Decision Trees

### Finding Content

```
Need to find something?
├── Know the channel? → ano messages read --channel <id> --agent
├── Need to search? → ano messages search "query" --agent
├── Which channels exist? → ano channels list --agent
├── Who's in the workspace? → ano users list --agent
├── Have a URL? → ano show <url> --agent
└── Multiple workspaces? → ano workspaces list --agent
```

### Sending Content

```
Want to send something?
├── To a channel by name → ano messages send "text" --channel-name engineering --agent  ← preferred (1 round trip)
├── To a channel by id   → ano messages send "text" --channel <id> --agent              ← when ID known (e.g. from <ano_payload>)
├── Reply in thread      → add --thread <msg_id>
├── With @mention        → add --mention <user_id>
├── With file attached   → add --file ./path.png  (repeat for multiple; empty content OK)
├── DM someone           → ano dm send "text" --to "Name" --agent                       ← 1 round trip
└── DM multiple people   → ano dm send "text" --to Alice --to Bob --to Carol --agent    ← group DM (Slack MPIM)
```

### Working with Tables

```
Need structured data (lists, databases, rows)?
├── What tables exist?   → ano tables list --agent
├── Schema + field IDs?  → ano tables get <table-id> --agent
├── Read rows?           → ano tables query <table-id> --agent
├── Filter rows?         → ano tables query <table-id> --filter '[{"field_id":"f1","operator":"eq","value":"done"}]' --agent
├── Add a row?           → ano tables get <table-id> --agent   (first, to learn field IDs)
│                        → ano tables create-item --table <table-id> --fields '{"<field_id>":"..."}' --agent
├── Edit a row?          → ano tables update-item <item-id> --fields '{"<field_id>":"..."}' --agent
├── Archive a row?       → ano tables update-item <item-id> --archive --agent
└── Comment on a row?    → ano tables comment <item-id> "body text" --agent
```

### Working with Automations

```
Building or managing an automation?
├── NEW automation (you are Claude Code) → BUILD-BEFORE-TALK below ↓
│   0. ensure a workspace is set: `ano workspaces list --agent`, then
│      `ano workspaces use <id>` if no active workspace (one-time per
│      profile). Without this, create-compiled will refuse with a
│      clear error pointing back here.
│   1. resolve named users/channels via ano user_get_by_name / channel_get_by_name
│   2. compose the compiled plan offline (see "Building Automations Offline")
│   3. validate locally → ano automation validate --file plan.json --agent
│   4. submit once     → ano automation create-compiled --file - --agent
├── Edit an existing one         → ano automation update <slug-or-id> --name "..." --agent
├── List existing                → ano automation list --agent
├── See recent runs              → ano automation runs <slug-or-id> --agent
├── Test before enabling         → ano automation run <slug-or-id> --agent  (dry-run)
├── Fire for real once           → ano automation run <slug-or-id> --no-dry-run --agent
├── Pause / resume               → ano automation pause|resume <slug-or-id>
├── Webhook trigger setup        → ano automation webhook-setup <slug-or-id> --agent
│   then activate to start firing → ano automation activate <slug-or-id> --agent
├── Needs a third-party service  → ano integrations connect <app> --agent (CLI v2.9.0+)
│   (Linear, Gmail, Notion, PostHog, etc. — see "Third-party connections" below)
└── Delete (irreversible)        → ano automation delete <slug-or-id>
```

#### Third-party connections (CLI v2.9.0+)

When the automation needs to read or write a third-party service the
user hasn't connected yet (any service in Pipedream's catalog —
Linear, GitHub, Gmail, Notion, HubSpot, PostHog, Slack, Salesforce,
etc.), ask them to authorize it BEFORE submitting the plan, otherwise
`pipedream_run` will fail at fire time with a missing-connection error.

```bash
ano integrations connect posthog --agent
```

The CLI returns a Pipedream OAuth URL. Surface it to the user as a
clickable link (the styled output already wraps it in OSC 8 for
terminals that support it; the `--agent` JSON envelope contains
`auth_url` for orchestrators that render their own UI). Once the user
finishes the OAuth in their browser, Pipedream calls back to Ano and
the connection is persisted automatically. The `expected_connection_name`
field tells you the deterministic name the persisted row will carry
(`pipedream:<app>:<userId>`) — useful for polling
`/api/connections?workspace_id=…` to detect completion before
submitting an automation that depends on it.

When composing the plan, the `automation_connections` row this creates
is referenceable from `sql_query` / `http_request` actions by its
`name` (`pipedream:<app>:<userId>`) — the engine looks the credential
up by that name at fire time.

> ⚠ **Engine-callable `pipedream_run` action is NOT live yet.** The
> connection persists, but the engine doesn't have a dedicated
> `pipedream_run` tool wired in — for now, use `http_request` against
> the third-party API directly with the connection's OAuth token. The
> dedicated action will land in a follow-up; until then,
> `ano integrations connect` is most useful for services the user wants
> Claude Code (the agent) to talk to via `ANO_REQUEST_CONNECTION` /
> `PIPEDREAM_RUN`, not for the automation engine.

#### Webhook automations are minted in stub mode (CLI v2.8.2+)

`ano automation webhook-setup <slug-or-id>` returns the URL + secret
but the token starts in **stub mode** — incoming events are recorded
for inspection but configured actions DON'T fire yet. This is
intentional for the desktop UI's recompile-on-real-payload flow, but
when you (Claude Code) build a webhook automation end-to-end you
almost always want it live immediately.

The two-step flow:

```bash
# 1. Mint the URL + secret
ano automation webhook-setup quiet-otter-42 --agent

# 2. Activate so inbound POSTs fire the actions
ano automation activate quiet-otter-42 --agent
```

The mint response's `next_step` field also contains the activate
hint — surface it to the user when they're setting up a webhook
integration so they don't lose silent webhook fires.

#### Slugs vs UUIDs (CLI v2.8.0+)

`ano automation list` returns each row with both a stable display
`slug` (e.g. `quiet-otter-42`) and the underlying `id` (UUID).
Every command that takes an automation positional now accepts either.

- **Humans + scrollback**: prefer the slug — it's readable, copy-pastes
  cleanly, and survives a glance from the user.
- **Scripts and `--json` consumers**: prefer the raw `id` — slugs are
  derived deterministically from the UUID but are display-only and
  could in principle change format in a future release.

The slug is computed client-side from the UUID via a stable hash, so
no server round-trip is needed to derive it. Resolution from slug → UUID
happens via a one-shot list call inside the command; if the slug is
ambiguous (extremely rare, single-workspace) the CLI prints the
matches and exits non-zero so the operator can re-run with the UUID.

> ⚠ **DO NOT use `ano new automation` from Bash inside a Claude Code session.**
>
> `ano new automation` is designed for a HUMAN running `claude` directly in
> their terminal — it spawns a _child_ `claude` subprocess and walks the user
> through a multi-turn spec build. From inside a Claude Code Bash call, every
> invocation spawns a _fresh_ subprocess with no shared state, so the user
> answers questions to a session that immediately exits and a new session
> asks the same questions again. If you are Claude Code, you ARE the agent
> — you don't need a child agent. Use **build-before-talk** instead: compose
> the full spec yourself using the trigger taxonomy + action vocabulary in
> the "Building Automations Offline" section, then submit it once via
> `ano automation create-compiled --file - --agent`. Sub-100ms server
> latency, no LLM roundtrip, no nested-session state loss.
>
> The same applies to `ano edit automation`. For edits, use
> `ano automation update <id> --field value --agent` (single-shot field
> updates) or compose a fresh plan and submit via `create-compiled`.

### Channel Admin (archive, members)

```
Managing a channel?
├── Archive (irreversible-ish, hides it)   → ano channels archive <channel-id> --agent
├── Add a teammate                         → ano channels member-add <channel-id> --user <user-id> --agent
├── Remove a teammate                      → ano channels member-remove <channel-id> --user <user-id> --agent
└── Need the user-id?                      → ano users list --agent  (find by display name or email)
```

Notes:

- Caller must be a workspace admin (or the channel creator) to archive.
- `member-add` rejects archived channels, non-channel types (DMs, spaces), and
  non-workspace users with crisp 400/404s — no opaque 500s.
- `member-remove` is a soft-delete (`removed_at` tombstone). The user can be
  re-added later and history is preserved.

### Workspace Admin (members)

```
Managing workspace membership?
├── Add a member (or rejoin)        → ano workspaces member-add <workspace-id> <user-id> --agent
├── Remove a member (soft-delete)   → ano workspaces member-remove <workspace-id> <user-id> --agent
├── Need the user-id?               → ano users list --agent  OR  ano user_get_by_email "alice@acme.com" --agent
└── List members                    → ano users list --agent
```

Notes:

- `member-add` is idempotent: rejoins removed members (clears `removed_at`),
  promotes 'collaborator' role to 'member', and is a no-op if already a full
  member. Auto-joins the user to the workspace's public channels in the same
  transaction.
- `member-remove` is a soft-delete. The user keeps their channel-membership
  history; reverse via `member-add`. Forbidden against the workspace's
  primary_owner — transfer ownership through the desktop UI first.
- Self-removal blocked: the "leave workspace" path is a separate flow
  (different audit trail, no `removed_by`). Use the desktop UI for that.

### Coworkers (AI teammates)

```
Need an AI teammate?
├── Managed (Anthropic-hosted, no infra)
│   → ano coworker create "Display Name" --role-title "Ops engineer" --agent
├── External (your own webhook endpoint, full control)
│   → ano coworker create "Display Name" --role-title "..." \
│       --external --webhook-url https://your.host/webhook --agent
│   ⚠ Response includes api_key + webhook_secret ONCE — save them now,
│      they are NOT recoverable later.
├── Test the webhook is reachable          → ano coworker webhook-test <coworker-id> --agent
├── Edit an existing coworker              → ano coworker update <coworker-id> [--field value …] --agent
│      ⚠ Only fields you pass are changed; everything else is left alone.
│      Toggling --enabled true/false sends an "Agent paused/resumed" DM.
├── Add to channels at create time         → --channels ch1,ch2,ch3
├── Limit to specific capabilities         → --capabilities send_message,read_table
└── Set persona/expertise                  → --expertise "..." --personality "..." --boundaries "..."
```

Pick managed unless the user has an existing service to call out to (a CRM,
their own LLM, a Linear bot). Managed is the default and the simpler path.

### DND & Notification Preferences

```
Adjusting how/when the user gets pinged?
├── Quiet hours (DND)
│   ├── Set window      → ano dnd set --start 22:00 --end 07:00 --agent
│   ├── Clear           → ano dnd set --clear --agent
│   └── Times are workspace-local (24h HH:MM); window may cross midnight.
├── Notification level (per-workspace)
│   ├── Everything           → ano notifications prefs-set --global-level everything --agent
│   ├── Mentions + DMs only  → ano notifications prefs-set --global-level mentions_dms --agent
│   └── Nothing              → ano notifications prefs-set --global-level nothing --agent
├── Email digests
│   ├── Disable        → ano notifications prefs-set --no-email --agent
│   ├── Enable + delay → ano notifications prefs-set --email --email-delay-minutes 5 --agent
├── Desktop / mobile push toggles
│   ├── ano notifications prefs-set --no-desktop --agent
│   └── ano notifications prefs-set --no-mobile --agent
```

`prefs-set` is a partial update — only the flags you pass change. Other
fields are preserved via `COALESCE`. So `--no-email` won't reset DND or push
settings.

### Setting Up Agent Access

```
├── Have API key? → ano auth login --key <key>
├── No key, need browser-based login (TTY) → ano auth login [--workspace-id <id>]
├── No key, need browser-based login (non-TTY orchestrator)
│   → ano auth login --print-workspaces  (step 1)
│   → ano auth complete --workspace-id <id>  (step 2)
├── Hit exit code 3 mid-task → see "Triggered Auth" above
├── One-off commands → use ano messages/channels/users directly
├── Persistent bridge → ano connect install-service
├── OpenClaw agent → ano connect --openclaw <url>
└── Diagnose issues → ano doctor --agent
```

## Common Workflows

### Post in a known channel — preferred one-shot pattern

```bash
# Single call. The server resolves "engineering" → id atomically with the insert.
ano messages send "Here's my analysis..." --channel-name engineering --agent
```

### Read a channel and reply

```bash
# Read still needs the id; resolve once via list, then reuse it for read + send.
channels=$(ano channels list --agent)
# Parse to find channel ID for "general"
messages=$(ano messages read --channel "$CHANNEL_ID" --limit 20 --agent)
ano messages send "Here's my analysis..." --channel "$CHANNEL_ID" --agent
```

### Search, then reply in thread

```bash
results=$(ano messages search "deployment issue" --agent)
# Extract channel_id and message_id from results
ano messages read --channel "$CHANNEL_ID" --limit 50 --agent
ano messages send "Fix applied" --channel "$CHANNEL_ID" --thread "$MSG_ID" --agent
```

### DM with user lookup

```bash
users=$(ano users list --agent)
# Find user ID for "Jane"
ano dm send "Can you review PR #42?" --to "Jane" --agent
```

### Group DM (Slack-style MPIM, CLI v2.17.0+)

When the user asks to "DM Alice and Bob" or "let Alice, Bob, and
Carol know that …", reach for the multi-recipient form. The server
finds-or-creates a single `group_dm` channel for that exact
participant set and posts the message. Idempotent — same recipients
forever land in the same channel (Slack convention; membership is
immutable, you can't add/remove members later).

```bash
# Repeat the flag (preferred for clarity in agent scripts)
ano dm send "ship gate at 17:00 — please confirm" \
  --to "Alice" --to "Bob" --to "Carol" --agent

# Comma-separated (terser)
ano dm send "ship gate at 17:00" --to "Alice,Bob,Carol" --agent

# Mix of names + ids — useful when you have one canonical id and one
# friendly name from earlier output
ano dm send "kick-off at 09:00" --to "Alice" --user-id usr_bob --agent
```

≥3 distinct members required (you + ≥2 others). Single recipient →
1:1 DM (existing behaviour). `--email` stays 1:1-only. The result
JSON has `"channel_type": "group_dm"` and `"recipients": [...]` so
agents can tell apart from a regular DM.

### Share a local file (CLI v2.18.0+)

When the user asks to "share the screenshot at /tmp/bug.png" or
"send Alice the build log", reach for `--file`. The flag works on
both `messages send` and `dm send`; the CLI uploads each file to R2
and posts the message + attachment row in one server-side
transaction. Empty content is allowed when at least one `--file` is
present (image-only sends).

```bash
# Single screenshot to a channel, with a caption
ano messages send "see screenshot for the bug repro" \
  --channel-name engineering --file ./bug.png --agent

# Multiple files in one send
ano messages send "logs from the failing run" \
  -c <id> --file ./out.txt --file ./err.txt --agent

# Image-only send (empty caption)
ano messages send "" --channel-name design --file ./shot.png --agent

# DM with attachment
ano dm send "report attached" --to "Alice" --file ./report.pdf --agent
```

Per-file cap: 25 MB. Per-invocation total: 125 MB (pre-flight
check). Supported types: images, video, audio, PDF, office docs,
text, JSON, zip/tar/gz. The result includes `attachment_ids: [...]`
so the agent can confirm the attachment row was written.

If the user already has the file in clipboard / a known temp path,
just call `--file` directly — no need to copy to a "shared" location
first.

### Verify the CLI ↔ API path is healthy (`ano dev smoke`)

When the user reports the CLI feels broken, or you want to confirm a
local dev stack is wired up, run a one-shot timed sweep instead of
poking commands one at a time. CLI v2.14.0+.

```bash
ano dev smoke --agent              # 5 ops + timings + daemon state
ano dev smoke --no-write --agent   # read-only (rate-limited envs)
ano --profile local dev smoke      # against the local dev stack
```

JSON envelope on `--agent`/`--json`: `{ ok, steps[], total_ms, daemon, endpoint }`.
Exit code is 0 on all-green, non-zero if any step failed. Pair with
`ano doctor --agent` if a step fails — doctor explains _why_, smoke
just measures _whether_.

### Daemon, cache, and circuit breaker (v2.20.0+)

The CLI ships a background daemon (`ano daemon`) that holds the Node
process warm + a TLS connection pool + a small in-process response
cache. Sequential CLI calls in the same shell session reuse all of
that and land in tens of milliseconds. There's a circuit breaker
that auto-disables a misbehaving daemon for 10 minutes so a wedged
daemon can never silently slow down every call.

**The model you should reason about:**

- First call: pays cold-start (~150-500 ms direct, or daemon-mediated
  if the daemon was pre-warmed by an earlier `ano daemon start`).
- Subsequent calls in the same workspace: cache hits land at ~40 ms.
- Cacheable reads: `list_workspaces`, `list_channels`, `list_users`,
  `list_tables`, `get_table` with 5 s TTL. Any write to the same
  origin invalidates the origin's cache.
- The breaker trips when the daemon doesn't reply within 10 s
  (truly wedged). It DOESN'T trip on normal-slow cloud calls — that
  was a v2.20.0 bug fixed in v2.21.3.

**`ano daemon status` shows the live state** (cache + breaker fields
present in CLI v2.20.0+):

```
status:  running
pid:     86737
socket:  /var/folders/.../ano-daemon-502.sock
uptime:  3m 12s
cli:     v2.21.3
proto:   v1
cache:   1 entries across 1 origin; 9 hits / 1 misses (90%); 0 invalidations
```

If you see `breaker: TRIPPED`, the daemon path is bypassed for the
remaining cooldown window. Calls fall back to direct execution
(~150 ms cold Node). To re-engage the daemon immediately, run
`ano daemon start` — it clears the breaker AND spawns a fresh
daemon.

**Debug cache behavior with `ANO_DEBUG_CACHE=1`** (CLI v2.21.0+):

```bash
ANO_DEBUG_CACHE=1 ano channels list
# stderr emits one line per fetch:
#   [ano:cache] MISS /mcp/list_channels (460B) +120.89ms — cached
#   [ano:cache] HIT  /mcp/list_channels (460B) +0.03ms
#   [ano:cache] WRITE /mcp/send_message +43.21ms — origin cache invalidated
```

Use this when timing feels off to confirm the cache is doing what
you think.

### Archive an old channel

```bash
# Find the channel
channels=$(ano channels list --agent)
# Extract channel ID for "old-project"
ano channels archive "$CHANNEL_ID" --agent
# Archived channels disappear from sidebars but messages are preserved.
```

### Add a teammate to a channel

```bash
# Look up the user
users=$(ano users list --agent)
# Find target user_id (by display name or email)
ano channels member-add "$CHANNEL_ID" --user "$USER_ID" --agent
# Idempotent: already-a-member returns 200, doesn't error.
# Rejects: archived channel (400), DM/space target (400), non-member of workspace (404).
```

### Create a managed AI teammate

```bash
# Anthropic-hosted, no infra to run.
ano coworker create "Iris" \
  --role-title "Customer support" \
  --expertise "answer billing questions, escalate refunds" \
  --boundaries "never promise refunds without a human approval" \
  --channels c123,c456 \
  --capabilities send_message,read_table \
  --agent
# No webhook needed. The coworker shows up in users list immediately.
```

### Create an external coworker (own webhook)

```bash
ano coworker create "Linear-Bot" \
  --role-title "Linear ops" \
  --external \
  --webhook-url https://bots.example.com/linear/webhook \
  --agent
# ⚠ Save api_key + webhook_secret from the response NOW.
# They are returned ONCE, not recoverable later.

# Verify the endpoint is reachable:
ano coworker webhook-test "$COWORKER_ID" --agent
```

### Set DND quiet hours

```bash
# Block notifications between 10pm and 7am workspace-local.
ano dnd set --start 22:00 --end 07:00 --agent

# Clear the window when on call:
ano dnd set --clear --agent
```

### Tighten notification level + email digest

```bash
# Only ping for @mentions and DMs:
ano notifications prefs-set --global-level mentions_dms --agent

# Disable email entirely:
ano notifications prefs-set --no-email --agent

# Or batch emails 5 minutes after the trigger fires:
ano notifications prefs-set --email --email-delay-minutes 5 --agent
# These calls are independent — partial update via COALESCE,
# so toggling email won't reset DND or push settings.
```

### Invite a teammate

```bash
ano invite alice@example.com --expires-hours 72
# Returns { token, invite_url, expires_at } — share invite_url with Alice.
# Re-running with the same email revokes the previous token first.
```

### Real-time bridge with OpenClaw

```bash
# Start persistent agent bridge
ano connect install-service \
  --key ano_cwk_... \
  --openclaw http://localhost:3000 \
  --health-port 8080

# Verify
curl http://127.0.0.1:8080/healthz
```

### stdin/stdout bridge protocol

Events stream as JSON lines on stdout:

```json
{"type":"connected","workspace":"Acme","channels":5,"members":12}
{"type":"message","channel_id":"...","content":"Hello","sender_name":"Jane"}
{"type":"dm","content":"Hey agent","sender_name":"Bob"}
```

Send commands on stdin:

```json
{"action":"send_message","channel_id":"...","content":"Hello"}
{"action":"send_dm","recipient_name":"Jane","content":"Hey"}
{"action":"typing","channel_id":"..."}
```

## Building Automations Offline (Build-Before-Talk)

**Lead-time rule:** when a user asks you to create an automation, build the
**complete spec** in chat first, then submit it to Ano in a single call. Do
NOT iterate via `automation compile` — that costs an LLM round-trip per
revision. The full spec language is documented below; you have everything
you need to design a valid plan offline.

The submission command is:

```bash
ano automation create-compiled --file - --agent <<'EOF'
{ ...the full plan JSON, schema below... }
EOF
```

It returns `{automation_id, name, enabled: false, ...}`. The automation
lands in `unconfirmed` state — the user approves it via the Automations
page or DM in Ano.

### Step 1: Gather workspace context BEFORE designing

You need IDs and names from the user's workspace to fill in the plan. One
batch of reads, then design offline:

```bash
ano channels list --agent      # channel IDs (note `is_public`, `has_guests`)
ano users list --agent         # user IDs + emails for send_dm
ano workspaces list --agent    # if multi-workspace, confirm which one
```

If the user mentions a coworker by name ("post as Maya"), also look at the
coworkers exposed in the workspace context. If the user mentions a SQL or
HTTP integration ("query our prod Postgres"), check whether the connection
exists — if not, you'll still emit the action and Ano will surface a
phantom Connect chip on the Automations page for the user to wire up.

### Step 2: Pick the trigger

There are exactly **five trigger types**. Pick the one that matches and
fill its `trigger_config`:

| `trigger_type`  | `trigger_config` shape                                             | When to use                                                    |
| --------------- | ------------------------------------------------------------------ | -------------------------------------------------------------- |
| `schedule`      | `{ cron: "0 9 * * 1-5", tz: "Europe/Stockholm" }`                  | Time-based (every weekday 9am, hourly, etc.)                   |
| `message_match` | `{ channel_id, pattern, sender_id? }`                              | Fire when a message in a channel matches a regex/string        |
| `mention`       | `{ channel_ids?: string[] }`                                       | Fire when @mentioned (workspace-wide unless channels narrowed) |
| `channel_event` | `{ channel_id, event_type: "reaction_added"\|"member_joined"... }` | Fire on a channel-level event                                  |
| `webhook`       | `{}` (config is empty; URL + signing secret minted after save)     | External system POSTs a payload                                |

**Cron grammar (5-field standard):** `minute hour dom mon dow`

- `minute` 0–59, `hour` 0–23, `dom` 1–31 or `*`, `mon` 1–12 or `*`, `dow` 0–6 or `*` (Sun=0)
- Lists (`1-5`), steps (`*/15`), and ranges (`9-17`) all work
- Always set `tz` explicitly. Default to the workspace timezone (read from `workspace.timezone`); fall back to `"UTC"` if unknown
- Examples: `"0 9 * * 1-5"` = 9am every weekday, `"*/15 * * * *"` = every 15 minutes, `"0 */4 * * *"` = top of every 4th hour

### Step 3: Compose the action chain

Five action tools are available. Use the **exact** tool names below
(verbatim — these are NOT CLI commands, they're runtime tool names the
automation engine resolves):

| `tool`         | `args` shape                                                                  | Output for chaining                                                                                                        |
| -------------- | ----------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `send_message` | `{ channel_id, content }`                                                     | (none — terminal action)                                                                                                   |
| `send_dm`      | `{ user_id, content }`                                                        | (none — terminal action)                                                                                                   |
| `sql_query`    | `{ connection: "<connection_name>", query: "SELECT ..." }`                    | `{{stepN.rows}}` (array)                                                                                                   |
| `http_request` | `{ connection?: "<name>", method: "GET"\|"POST"\|..., url, headers?, body? }` | `{{stepN.body.PATH}}` — **PROBE the endpoint with `curl` first to verify PATH actually exists in the response (Step 3.5)** |
| `run_skill`    | `{ skill_id, args }`                                                          | `{{stepN.output}}`                                                                                                         |

For third-party services that don't have a stable HTTP API the user
wants to hand-write — Linear, Gmail, Notion, HubSpot, etc. — use
`http_request` with the OAuth-managed connection that
`ano integrations connect <app>` produces (see the "Third-party
connections" decision-tree subsection). A dedicated `pipedream_run`
action that hides the HTTP shape entirely is planned but not yet engine-
callable; track it in the Ano monorepo.

**Template variables (chaining):** earlier-step outputs are interpolated
into later-step args using `{{stepN.PATH}}`:

- `{{step1.rows.length}}` — count of SQL rows
- `{{step1.rows.0.name}}` — first row's `name` column
- `{{step2.body.user.email}}` — nested field from an HTTP response

`stepN` is **1-indexed** in the order they appear in `actions[]`.

**Sender attribution** (`sender_kind` at the top level of the plan):

- `bot` (default) — generic Ano bot avatar
- `coworker` — pair with `coworker_id`; messages appear from that coworker
- `human` — posts as the human owner; **the safety lint warns on this**
  because channel members may think the human typed it manually

`bot_avatar` is an optional single emoji (e.g. `"📊"`).

### Step 3.5: Probe HTTP endpoints — REQUIRED before saving

**If the plan contains an `http_request` action whose output you reference via `{{stepN.body…}}`, you MUST first probe the endpoint and verify the field path exists in the actual response.** Do not infer the response shape from the URL or the user's description.

```bash
# 1. Probe the real endpoint (no auth header? no headers needed)
curl -s 'https://api.example.com/v1/thing?param=x' | head -c 1000

# 2. Confirm the path you intend to template lands at a real value, not undefined
#    e.g. body.current.temperature_2m → 11.8 (✓), not body.data.temp (✗)
```

Then bake the **verified** path into the action template. If the body is wrapped (e.g. `{ data: {...} }` or paginated), follow the wrapper. If the value is nested deeper than you expected, fix the template before saving.

**After saving, also verify rendering** with a real test fire (not just dry-run — dry-run does not exercise template substitution against live data):

```bash
ano automation run <slug-or-id> --no-dry-run --agent
ano messages read --channel <dm-channel-id> --limit 1 --agent
# Check that the delivered message contains real values, not empty placeholders
# like "Temp: °C" — that means the path didn't resolve and the engine silently
# rendered an empty string.
```

If you skip this and the template path is wrong, runs will report `success` but recipients receive messages with empty placeholders. The engine does not fail loudly on missing template paths.

This applies equally when **editing** an existing automation's `actions` (i.e. via `ano automation update --actions ...` or the `ano edit automation` walk-through). Probe before changing the template; verify after.

### Step 4: Apply safety rules BEFORE submitting

Pre-check the plan against these rules — they're what Ano's safety lint
will warn on. Fixing them in chat is faster than after-the-fact warnings.

| Rule                                 | What to do                                                                                                                   |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| `SELECT *` going to a public channel | Always add a `LIMIT N` (typically 50). Unbounded `SELECT *` → public channel = channel flood.                                |
| Sensitive columns in SQL             | Avoid `password`, `secret`, `token`, `api_key`, `salt`, `private_key`, `credit_card`, `ssn`. Mask at query time or refuse.   |
| Posting as `human`                   | Default to `bot` unless the user explicitly asks. If `human`, warn the user that channel members will see it as their voice. |
| Public-channel destination           | If posting to a public channel, mention this to the user (they may want a private channel instead).                          |
| Guest-visible channel                | If `has_guests=true` on the destination channel, flag it — guests will see the output.                                       |
| Connection name not found            | Still emit the action; warn the user the connection chip will be phantom until they wire it up.                              |

### Step 4b: Run caps (when the user phrases a limit)

If the user describes a cap — "for 5 weeks", "20 times", "until end of
Q2", "for the next month", "just once" — set them in the plan / on
submit. The engine auto-disables the automation when the cap is
reached (preserves run history; user can raise the cap and re-enable).

Two cap fields, either or both can be set:

| Field        | Type           | Set via plan JSON             | Set via flag                                          |
| ------------ | -------------- | ----------------------------- | ----------------------------------------------------- |
| `max_runs`   | positive int   | `"max_runs": 20`              | `--max-runs 20`                                       |
| `expires_at` | epoch ms (UTC) | `"expires_at": 1717200000000` | `--expires-in "5 weeks"` OR `--expires-at 2026-06-01` |

Phrasing → field mapping:

- "for 5 weeks" / "next month" / "until June 1" → `--expires-in` or
  `--expires-at`
- "20 times" / "5 runs" / "just once" → `max_runs`
- "every weekday for a month" → both: schedule cron + `--expires-in "1 month"`

Surface the cap in the plain-English recap (Step 5):

> "Got it: every weekday at 09:00 Stockholm time, post yesterday's
> signups to #growth, **for the next 5 weeks** (auto-disables on
> {date}). Confirm?"

When the cap is reached, the engine sets `enabled=false` and
`last_error="cap reached: <max_runs|expired>"`. The user can
`ano automation update <slug> --max-runs 100 --enabled true` (or
similar) to extend.

### Step 5: Interview script

When the user says "create an automation", run this interview in chat
**before** any Ano calls. The goal is to walk away with every field of
the plan filled in:

1. **Trigger:**
   - "When should this fire — on a schedule, when someone messages a channel, when you're @mentioned, on a channel event, or when an external system pings a webhook?"
   - If schedule: "What cadence and at what time / timezone?"
   - If message_match: "Which channel? What pattern should match?"
2. **Actions:**
   - "What should it do? Walk me through the steps in order."
   - For each step, identify which of the 5 tools applies. If the user says "post in Slack" they probably mean `send_message` to an Ano channel.
   - For SQL/HTTP steps, ask which connection.
   - If outputs from earlier steps need to flow in, build the `{{stepN...}}` reference yourself — don't ask the user to write template syntax.
3. **Sender:** "Should this post as a bot, as one of your coworkers (which one?), or as you?"
4. **Run caps:** if the user phrased a duration / count limit ("for 5 weeks", "20 times"), apply Step 4b. Otherwise leave both unset (unlimited).
5. **Name:** propose one based on the prompt; let the user override.
6. **Recap:** read the plan back in plain English. Include any cap. **Don't show JSON** unless asked. Confirm.
7. **Submit:** one shot — `ano automation create-compiled --file - --agent` (with `--max-runs` / `--expires-in` / `--expires-at` if set).

### Worked examples

#### Example 1 — Daily digest from Postgres

User: _"Every weekday at 9am Stockholm time, post the count of new signups from yesterday to #growth."_

```json
{
  "trigger_type": "schedule",
  "trigger_config": { "cron": "0 9 * * 1-5", "tz": "Europe/Stockholm" },
  "actions": [
    {
      "tool": "sql_query",
      "args": {
        "connection": "neon-prod",
        "query": "SELECT COUNT(*) AS n FROM users WHERE created_at::date = CURRENT_DATE - 1 LIMIT 1"
      }
    },
    {
      "tool": "send_message",
      "args": {
        "channel_id": "ch_abc123",
        "content": "📊 New signups yesterday: {{step1.rows.0.n}}"
      }
    }
  ],
  "name": "Daily signup count → #growth",
  "sender_kind": "bot",
  "bot_avatar": "📊"
}
```

#### Example 2 — Mention-triggered triage

User: _"When @mentioned in #support, query our HelpScout API and DM me the open ticket count."_

```json
{
  "trigger_type": "mention",
  "trigger_config": { "channel_ids": ["ch_support_xyz"] },
  "actions": [
    {
      "tool": "http_request",
      "args": {
        "connection": "helpscout",
        "method": "GET",
        "url": "https://api.helpscout.net/v2/conversations?status=active"
      }
    },
    {
      "tool": "send_dm",
      "args": {
        "user_id": "u_user_789",
        "content": "Open tickets: {{step1.body._embedded.conversations.length}}"
      }
    }
  ],
  "name": "Mention in #support → DM ticket count",
  "sender_kind": "bot"
}
```

#### Example 3 — Webhook to channel

User: _"When Stripe webhooks us a charge.failed event, post the customer email to #billing-alerts."_

```json
{
  "trigger_type": "webhook",
  "trigger_config": {},
  "actions": [
    {
      "tool": "send_message",
      "args": {
        "channel_id": "ch_billing_alerts",
        "content": "❌ Charge failed for {{step0.body.data.object.receipt_email}} — amount {{step0.body.data.object.amount}}"
      }
    }
  ],
  "name": "Stripe charge.failed → #billing-alerts",
  "sender_kind": "bot",
  "bot_avatar": "❌"
}
```

(For webhooks, `{{step0.body.*}}` references the inbound payload.)

#### Example 4 — Hourly DM with named-user resolution (the canonical Claude-Code-from-chat flow)

User: _"DM Leo every hour during work hours with the weather in Stockholm. Fetch from open-meteo.com."_

This is the case the build-before-talk path was designed for. Walk through it end-to-end so the user gets one fast, flawless flow instead of a multi-turn dance with state loss.

**Step 1 — Resolve "Leo" to a user_id (one stateless probe):**

```bash
ano user_get_by_name "Leo" --agent
# Returns { user_id: "user_01KGDB7J4R8VEEJ2FNCV0AMPDR", display_name: "Leo Nilsson", … }
```

If the name is ambiguous (multiple matches), fall back to `ano users list --agent` and pick the right row. **Don't ask the user for the ID** — they shouldn't have to know it.

**Step 2 — Compose the plan offline:**

```json
{
  "trigger_type": "schedule",
  "trigger_config": { "cron": "0 9-17 * * 1-5", "tz": "Europe/Stockholm" },
  "actions": [
    {
      "tool": "http_request",
      "args": {
        "method": "GET",
        "url": "https://api.open-meteo.com/v1/forecast?latitude=59.3293&longitude=18.0686&current=temperature_2m,weather_code,wind_speed_10m"
      }
    },
    {
      "tool": "send_dm",
      "args": {
        "user_id": "user_01KGDB7J4R8VEEJ2FNCV0AMPDR",
        "content": "Stockholm weather: {{step1.body.current.temperature_2m}}°C, wind {{step1.body.current.wind_speed_10m}} km/h"
      }
    }
  ],
  "name": "Hourly Stockholm weather → Leo",
  "sender_kind": "bot",
  "bot_avatar": "☀️"
}
```

`0 9-17 * * 1-5` = at minute 0 of hours 9-17 (so 9, 10, …, 17) on Mon-Fri. Workspace timezone is Europe/Stockholm; the cron is interpreted in that tz.

**Step 3 — Validate offline:**

```bash
echo '{...plan...}' | ano automation validate --file - --agent
# OR write to /tmp/plan.json first if the plan is large:
ano automation validate --file /tmp/plan.json --agent
```

**Step 4 — Read the plan back in plain English and confirm with the user.** Do NOT show JSON. Just say:

> "Every weekday from 9am to 5pm Stockholm time, on the hour, I'll fetch the current Stockholm weather from open-meteo and DM Leo a one-line summary (temperature + wind). Confirm?"

**Step 5 — On confirm, submit once:**

```bash
cat /tmp/plan.json | ano automation create-compiled --file - --agent
# Returns { id: "auto_…", next_fire_at: "2026-05-04T08:00:00Z", … }
```

**Step 6 — Report back:**

> "Created. First fire in 47 minutes."

Total elapsed: ~2 seconds, no nested-Claude-Code session, no state loss between Bash invocations. **This is the flow for any from-chat automation request — never `ano new automation`.**

### Validation checklist before submitting

- [ ] `trigger_type` is one of the five literals
- [ ] `trigger_config` matches the shape for that trigger type
- [ ] If `schedule`: `cron` parses as 5 fields; `tz` is set
- [ ] `actions` has at least one entry
- [ ] Every `tool` is one of the five literals
- [ ] Every `channel_id` / `user_id` / `connection` resolves to something the user named in the interview
- [ ] Every `{{stepN.PATH}}` reference points at a step that produces that output
- [ ] **For each `http_request` template ref: I have curled the endpoint and confirmed `PATH` resolves to a real value in the actual response (Step 3.5). Skipping this means runs will silently deliver empty placeholders.**
- [ ] `name` is ≤80 chars and human-readable
- [ ] `sender_kind` is set; `coworker_id` is present iff `sender_kind="coworker"`
- [ ] No `SELECT *` to a public channel without a `LIMIT`
- [ ] No sensitive-column patterns in SQL queries

### After submission

```bash
# Submit the spec
ano automation create-compiled --file - --agent <<EOF
{...}
EOF
# → {"id":"auto_abc","name":"…","enabled":false,...}

# Verify
ano automation list --agent

# Test (dry-run) before enabling
ano automation run auto_abc --agent

# Fire for real once
ano automation run auto_abc --no-dry-run --agent
```

The user enables it in the Ano UI — that's a deliberate human gate so an
automation can never silently start firing.

## Exit Codes

| Code | Name       | Meaning             | Fix                                                          |
| ---- | ---------- | ------------------- | ------------------------------------------------------------ |
| 0    | OK         | Success             | —                                                            |
| 1    | USAGE      | Bad arguments       | `ano <cmd> --help`                                           |
| 2    | NOT_FOUND  | Resource missing    | Verify ID/URL                                                |
| 3    | AUTH       | Invalid/missing key | Run **Triggered Auth** flow (see above) — don't dump on user |
| 4    | FORBIDDEN  | No permission       | Check key scopes                                             |
| 5    | RATE_LIMIT | 60/min exceeded     | Wait 10s, retry                                              |
| 6    | NETWORK    | Connection failed   | `ano doctor --agent`                                         |
| 7    | API_ERROR  | Server error        | Retry                                                        |

## Authentication

Resolution chain (highest priority first):

1. `--key` flag
2. `ANO_API_KEY` environment variable
3. `.ano/config.json` (project-level)
4. `~/.config/ano/credentials.json` (global, via `ano auth login`)

```bash
# Save credentials (programmatic — paste a key)
ano auth login --key ano_cwk_... --endpoint https://api-staging.ano.dev

# Browser login (interactive TTY)
ano auth login --workspace-id <id>

# Browser login (non-TTY orchestrator) — see "Triggered Auth" section
ano auth login --print-workspaces
ano auth complete --workspace-id <id>

# Check
ano auth status --agent

# For non-default endpoints
ano auth login --key ano_cwk_... --endpoint https://api-staging.ano.dev --profile staging
```

## Configuration

```
~/.config/ano/
├── credentials.json    # API keys per profile
├── config.json         # Global defaults
└── .session            # Short-lived OAuth token cache (between
                        # `auth login --print-workspaces` and `auth complete`)

.ano/
└── config.json         # Project-level overrides (workspace_id, endpoint)
```

| Env Variable             | Description                                                                |
| ------------------------ | -------------------------------------------------------------------------- |
| `ANO_API_KEY`            | API key                                                                    |
| `ANO_ENDPOINT`           | API endpoint (default: https://api.ano.dev)                                |
| `ANO_WORKSPACE_ID`       | Default workspace                                                          |
| `ANO_PROFILE`            | Profile name from credentials.json (CLI v2.15.0+)                          |
| `ANO_NO_AUTO_LOCAL`      | Set to `1` to disable monorepo auto-pick of `local` profile (CLI v2.16.0+) |
| `ANO_QUIET_PROFILE_HINT` | Set to `1` to suppress the stderr hint when auto-pick fires                |
| `NO_COLOR`               | Disable ANSI colors                                                        |

### Profile auto-pick (CLI v2.16.0+)

When the CLI is invoked from a CWD under a directory with a running
`dev:local` stack (signal: `.ano/dev/postgres/postmaster.pid` exists
in CWD or an ancestor), AND a `local` profile exists in
`credentials.json`, the CLI uses `local` automatically instead of
sending to `default` (typically staging).

**It always prints the choice to stderr** so it's never invisible:

```
→ profile: local (auto — dev:local stack detected; pass --profile default to override)
```

**Read this hint.** If a CLI call writes data and the user doesn't see
it appear where they expect, check the stderr line first — the
operation may have hit a different env than they assumed. To force
staging from inside the monorepo:

```bash
ano --profile default messages send "..." --channel-name design --agent
# or
ANO_PROFILE=default ano messages send "..." --channel-name design --agent
```

The auto-pick does NOT fire when `--profile`, `--key`, `ANO_API_KEY`,
or a project `.ano/config.json` was set explicitly.

## Event Types (SSE Bridge)

| Type              | Trigger         | Key Fields                                 |
| ----------------- | --------------- | ------------------------------------------ |
| `message`         | Channel message | channel_id, content, sender_name, mentions |
| `thread_reply`    | Thread reply    | channel_id, thread_id, content, parent     |
| `dm`              | Direct message  | channel_id, content, sender_name           |
| `reaction`        | Emoji reaction  | message_id, emoji, sender_name             |
| `channel_added`   | Joined channel  | channel_id, user_id                        |
| `channel_removed` | Left channel    | channel_id, user_id                        |

Agent mode (`--openclaw`) auto-responds to DMs, thread replies, and @mentions.

## Rate Limiting

- 60 requests/minute per API key, sliding window
- Headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`
- CLI retries automatically on 429 with backoff
- Batch reads with `--limit` instead of many small requests
- A typical workflow (list channels + read + send) uses 3 of 60 requests

## Learn More

- CLI repo: https://github.com/LeoNilsson/ano-cli
- Ano: https://ano.dev
