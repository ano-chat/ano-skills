---
name: ano-automations
description: |
  Build, edit, run, and manage Ano automations via the `ano` CLI. Covers
  scheduled jobs, message-match / mention / channel-event / webhook
  triggers, the 5-action vocabulary (send_message, send_dm, sql_query,
  http_request, run_skill), template chaining, run caps, third-party
  OAuth connections (Linear, Gmail, Notion, PostHog, HubSpot, etc.), and
  the Build-Before-Talk methodology that submits a compiled plan in one
  call. Self-contained.
triggers:
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
invocable: true
argument-hint: "[command] [args...]"
---

# Ano CLI — Automations (Build-Before-Talk)

## Essentials

- Output: `--agent` for raw JSON, `--json` for envelope. Never parse styled TTY.
- IDs are UUIDs — never fabricate. `ano channels list --agent` / `ano users list --agent` resolve names.
- Exit codes: 0 OK · 1 USAGE · 2 NOT_FOUND · 3 AUTH · 4 FORBIDDEN · 5 RATE_LIMIT.
- On exit 3 (AUTH), orchestrate the triggered-auth flow inline.
- **Lead-time rule**: build the complete spec in chat first, then submit in ONE call via `create-compiled`. Do NOT iterate via `automation compile` — that's an LLM round-trip per revision.

## Decision tree

```
Building or managing an automation?
├── NEW automation (you are Claude Code) → BUILD-BEFORE-TALK below ↓
│   0. ensure a workspace is set: `ano workspaces list --agent`,
│      then `ano workspaces use <id>` if no active workspace.
│      Without this, create-compiled refuses with a clear error.
│   1. resolve named users/channels via ano user_get_by_name / channel_get_by_name
│   2. compose the compiled plan offline (see Steps 1–5 below)
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
│                                  (Linear, Gmail, Notion, PostHog, HubSpot, etc.)
└── Delete (irreversible)        → ano automation delete <slug-or-id>
```

## Quick reference

| Task                                  | Command                                                            |
| ------------------------------------- | ------------------------------------------------------------------ |
| Submit a compiled plan                | `ano automation create-compiled --file plan.json --agent`          |
| Submit from stdin                     | `cat plan.json \| ano automation create-compiled --file - --agent` |
| Validate offline first                | `ano automation validate --file plan.json --agent`                 |
| Compile only (no save)                | `ano automation compile "prompt" --agent`                          |
| Create from prompt (server LLM, slow) | `ano automation create "prompt" --agent`                           |
| Update                                | `ano automation update <slug-or-id> --name "..." --agent`          |
| List (returns slug + id)              | `ano automation list --agent`                                      |
| Recent runs                           | `ano automation runs <slug-or-id> --agent`                         |
| Test (dry-run)                        | `ano automation run <slug-or-id> --agent`                          |
| Run for real                          | `ano automation run <slug-or-id> --no-dry-run --agent`             |
| Pause / Resume                        | `ano automation pause\|resume <slug-or-id>`                        |
| Delete                                | `ano automation delete <slug-or-id>`                               |
| Webhook setup/rotate                  | `ano automation webhook-setup <slug-or-id> --agent`                |
| Activate webhook (stub → live)        | `ano automation activate <slug-or-id> --agent` (CLI v2.8.2+)       |

## Slugs vs UUIDs (CLI v2.8.0+)

`ano automation list` returns both `slug` (e.g. `quiet-otter-42`) and `id` (UUID). Every command that takes an automation positional accepts either.

- **Humans + scrollback**: prefer the slug (readable, copy-paste).
- **Scripts and `--json` consumers**: prefer the raw `id` (slugs are display-only).

Slugs are derived deterministically from the UUID client-side. Ambiguous slug (rare) → CLI exits non-zero with matches printed.

## ⚠ Do NOT use `ano new automation` / `ano edit automation` from Bash

These spawn a **child** `claude` subprocess for a multi-turn interview. From inside a Claude Code Bash call, each invocation is a fresh subprocess with no shared state — the user answers questions to a session that immediately exits and a new session asks the same questions again.

If you are Claude Code, you ARE the agent. Use **Build-Before-Talk** below: compose the spec yourself, then `create-compiled --file - --agent` in one shot. Sub-100ms server latency, no LLM round-trip, no nested-session state loss.

For edits: `ano automation update <id> --field value --agent` (single-shot) OR re-compose + `create-compiled`.

## Building Automations Offline (Build-Before-Talk)

The submission command:

```bash
ano automation create-compiled --file - --agent <<'EOF'
{ ...the full plan JSON, schema below... }
EOF
```

Returns `{automation_id, name, enabled: false, ...}`. Lands in `unconfirmed` state — user approves it via the Automations page or DM.

### Step 1: Gather workspace context BEFORE designing

```bash
ano channels list --agent      # channel IDs (note is_public, has_guests)
ano users list --agent         # user IDs + emails for send_dm
ano workspaces list --agent    # if multi-workspace, confirm which one
```

If the user mentions a coworker by name ("post as Maya"), look at workspace coworkers. If the user mentions a SQL/HTTP integration ("query our prod Postgres"), check whether the connection exists — if not, still emit the action; Ano surfaces a phantom Connect chip on the Automations page.

### Step 2: Pick the trigger (5 types)

| `trigger_type`  | `trigger_config` shape                                             | When                                                           |
| --------------- | ------------------------------------------------------------------ | -------------------------------------------------------------- |
| `schedule`      | `{ cron: "0 9 * * 1-5", tz: "Europe/Stockholm" }`                  | Time-based (every weekday 9am, hourly, etc.)                   |
| `message_match` | `{ channel_id, pattern, sender_id? }`                              | Fire when a message in a channel matches a regex/string        |
| `mention`       | `{ channel_ids?: string[] }`                                       | Fire when @mentioned (workspace-wide unless channels narrowed) |
| `channel_event` | `{ channel_id, event_type: "reaction_added"\|"member_joined"... }` | Fire on a channel-level event                                  |
| `webhook`       | `{}` (URL + signing secret minted after save)                      | External system POSTs a payload                                |

**Cron grammar (5-field standard):** `minute hour dom mon dow`

- `minute` 0–59, `hour` 0–23, `dom` 1–31 or `*`, `mon` 1–12 or `*`, `dow` 0–6 or `*` (Sun=0)
- Lists (`1-5`), steps (`*/15`), ranges (`9-17`) all work
- Always set `tz` explicitly. Default to workspace timezone; fall back to `"UTC"` if unknown.
- Examples: `"0 9 * * 1-5"` = 9am weekdays · `"*/15 * * * *"` = every 15 min · `"0 */4 * * *"` = top of every 4th hour

### Step 3: Compose the action chain (5 tools)

Use these EXACT tool names (NOT CLI commands — runtime tool names):

| `tool`         | `args` shape                                                                  | Output for chaining                                                                                                        |
| -------------- | ----------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `send_message` | `{ channel_id, content }`                                                     | (none — terminal)                                                                                                          |
| `send_dm`      | `{ user_id, content }`                                                        | (none — terminal)                                                                                                          |
| `sql_query`    | `{ connection: "<connection_name>", query: "SELECT ..." }`                    | `{{stepN.rows}}` (array)                                                                                                   |
| `http_request` | `{ connection?: "<name>", method: "GET"\|"POST"\|..., url, headers?, body? }` | `{{stepN.body.PATH}}` — **PROBE the endpoint with `curl` first to verify PATH actually exists in the response (Step 3.5)** |
| `run_skill`    | `{ skill_id, args }`                                                          | `{{stepN.output}}`                                                                                                         |

For third-party services (Linear, Gmail, Notion, HubSpot, etc.), use `http_request` with the OAuth connection that `ano integrations connect <app>` produces. A dedicated `pipedream_run` action is planned but not yet engine-callable.

**Template variables**: earlier-step outputs interpolated as `{{stepN.PATH}}`:

- `{{step1.rows.length}}` — count of SQL rows
- `{{step1.rows.0.name}}` — first row's `name` column
- `{{step2.body.user.email}}` — nested HTTP response field

`stepN` is **1-indexed** in the order they appear in `actions[]`. Webhook payloads reference as `{{step0.body.*}}`.

**Sender attribution** (`sender_kind` at plan top-level):

- `bot` (default) — generic Ano bot avatar
- `coworker` — pair with `coworker_id`; messages appear from that coworker
- `human` — posts as the human owner; **safety lint warns** (channel members may think the human typed it)

`bot_avatar` is an optional single emoji (e.g. `"📊"`).

### Step 3.5: Probe HTTP endpoints — REQUIRED before saving

If the plan contains an `http_request` whose output you reference via `{{stepN.body…}}`, you MUST probe the endpoint and verify the field path. Do NOT infer the response shape from the URL.

```bash
# 1. Probe the real endpoint
curl -s 'https://api.example.com/v1/thing?param=x' | head -c 1000

# 2. Confirm the path lands at a real value
#    e.g. body.current.temperature_2m → 11.8 ✓
#         body.data.temp              → undefined ✗
```

Bake the **verified** path into the template. If the body is wrapped or paginated, follow the wrapper.

**After saving, verify rendering** with a real test fire (NOT just dry-run — dry-run doesn't exercise template substitution):

```bash
ano automation run <slug-or-id> --no-dry-run --agent
ano messages read --channel <dm-channel-id> --limit 1 --agent
# Check the delivered message contains real values, not empty placeholders
# (e.g. "Temp: °C" means the path didn't resolve — engine silently empties).
```

If you skip this and the template path is wrong, runs report `success` but recipients receive empty placeholders. The engine does NOT fail loudly on missing template paths.

Same rule applies when **editing** actions via `ano automation update --actions ...`: probe before, verify after.

### Step 4: Apply safety rules BEFORE submitting

| Rule                                 | What to do                                                                                                                 |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| `SELECT *` going to a public channel | Add `LIMIT N` (typically 50). Unbounded `SELECT *` → public = channel flood.                                               |
| Sensitive columns in SQL             | Avoid `password`, `secret`, `token`, `api_key`, `salt`, `private_key`, `credit_card`, `ssn`. Mask at query time or refuse. |
| Posting as `human`                   | Default to `bot` unless user explicitly asks. If `human`, warn the user channel members will see it as their voice.        |
| Public-channel destination           | Mention it to the user — they may want a private channel instead.                                                          |
| Guest-visible channel                | If `has_guests=true` on destination, flag it — guests see the output.                                                      |
| Connection name not found            | Still emit the action; warn the user the connection chip will be phantom until they wire it up.                            |

### Step 4b: Run caps (when the user phrases a limit)

"for 5 weeks" / "20 times" / "until end of Q2" / "just once" → set caps. Engine auto-disables on cap reached; user can extend.

| Field        | Type           | In plan JSON                  | On submit flag                                        |
| ------------ | -------------- | ----------------------------- | ----------------------------------------------------- |
| `max_runs`   | positive int   | `"max_runs": 20`              | `--max-runs 20`                                       |
| `expires_at` | epoch ms (UTC) | `"expires_at": 1717200000000` | `--expires-in "5 weeks"` OR `--expires-at 2026-06-01` |

Phrasing → field:

- "for 5 weeks" / "next month" / "until June 1" → `--expires-in` / `--expires-at`
- "20 times" / "5 runs" / "just once" → `max_runs`
- "every weekday for a month" → both: schedule cron + `--expires-in "1 month"`

Surface in plain-English recap (Step 5):

> "Got it: every weekday at 09:00 Stockholm time, post yesterday's signups to #growth, **for the next 5 weeks** (auto-disables on {date}). Confirm?"

On cap reached: engine sets `enabled=false`, `last_error="cap reached: <max_runs|expired>"`. Extend with `ano automation update <slug> --max-runs 100 --enabled true`.

### Step 5: Interview script

Run this in chat BEFORE any Ano calls. Goal: walk away with every plan field filled in.

1. **Trigger**: schedule / message_match / mention / channel_event / webhook? If schedule, cadence + tz. If message_match, channel + pattern.
2. **Actions**: walk the steps in order. Identify which of the 5 tools applies. ("post in Slack" almost always means `send_message` to an Ano channel.) For SQL/HTTP steps, ask which connection. For `{{stepN...}}` references, build them yourself — don't ask the user to write template syntax.
3. **Sender**: bot / coworker (which one) / human?
4. **Run caps**: if the user phrased a duration/count limit, apply Step 4b. Otherwise unlimited.
5. **Name**: propose one; let the user override.
6. **Recap in plain English**, include any cap, **don't show JSON** unless asked, confirm.
7. **Submit**: one shot — `ano automation create-compiled --file - --agent` (with `--max-runs` / `--expires-in` / `--expires-at` if set).

## Third-party connections (CLI v2.9.0+)

When the automation needs a third-party service the user hasn't connected yet (any service in Pipedream's catalog — Linear, GitHub, Gmail, Notion, HubSpot, PostHog, Slack, Salesforce, etc.), ask them to authorize BEFORE submitting, otherwise the action fails at fire time with missing-connection.

```bash
ano integrations connect posthog --agent
```

CLI returns a Pipedream OAuth URL. Surface as clickable link (styled output wraps in OSC 8; `--agent` envelope has `auth_url`). After user finishes OAuth, Pipedream calls back to Ano and the connection persists. The `expected_connection_name` field shows the deterministic persisted name (`pipedream:<app>:<userId>`) — useful for polling `/api/connections?workspace_id=…` to detect completion.

When composing the plan, reference the connection by `name` in `sql_query` / `http_request` actions — the engine looks the credential up by that name at fire time.

> ⚠ Engine-callable `pipedream_run` is NOT live yet. Connection persists, but no dedicated tool wired in. For now, use `http_request` against the third-party API directly with the connection's OAuth token. Dedicated action lands in a follow-up.

## Webhook automations: stub mode (CLI v2.8.2+)

`ano automation webhook-setup <slug-or-id>` returns URL + secret but the token starts in **stub mode** — incoming events recorded for inspection but actions DON'T fire. Intentional for the desktop UI's recompile-on-real-payload flow. When you (Claude Code) build a webhook automation end-to-end, you almost always want it live immediately.

```bash
# 1. Mint the URL + secret
ano automation webhook-setup quiet-otter-42 --agent

# 2. Activate so inbound POSTs fire actions
ano automation activate quiet-otter-42 --agent
```

The mint response's `next_step` field contains the activate hint — surface to the user so they don't lose silent webhook fires.

## Worked examples

### Example 1 — Daily digest from Postgres

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

### Example 2 — Mention-triggered triage

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

### Example 3 — Webhook to channel

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

(Webhooks reference inbound payload as `{{step0.body.*}}`.)

### Example 4 — Hourly DM with named-user resolution (canonical from-chat flow)

User: _"DM Leo every hour during work hours with the weather in Stockholm. Fetch from open-meteo.com."_

**Step 1 — Resolve "Leo" to user_id (one stateless probe):**

```bash
ano user_get_by_name "Leo" --agent
# → { user_id: "user_01KGDB7J4R8VEEJ2FNCV0AMPDR", display_name: "Leo Nilsson", … }
```

Ambiguous name → fall back to `ano users list --agent` and pick. Don't ask the user for the ID.

**Step 2 — Compose offline:**

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

`0 9-17 * * 1-5` = at minute 0 of hours 9–17 on Mon–Fri, interpreted in Europe/Stockholm.

**Step 3 — Validate offline:**

```bash
echo '{...plan...}' | ano automation validate --file - --agent
```

**Step 4 — Plain-English recap, confirm with user.** Do NOT show JSON.

> "Every weekday from 9am to 5pm Stockholm time, on the hour, I'll fetch the current Stockholm weather from open-meteo and DM Leo a one-line summary (temperature + wind). Confirm?"

**Step 5 — On confirm, submit once:**

```bash
cat /tmp/plan.json | ano automation create-compiled --file - --agent
# → { id: "auto_…", next_fire_at: "2026-05-04T08:00:00Z", … }
```

**Step 6 — Report back:**

> "Created. First fire in 47 minutes."

Total elapsed: ~2 seconds. No nested-Claude-Code session. No state loss between Bash invocations. **This is the flow for any from-chat automation request — never `ano new automation`.**

## Validation checklist before submitting

- [ ] `trigger_type` is one of the five literals
- [ ] `trigger_config` matches the shape for that trigger type
- [ ] If `schedule`: `cron` parses as 5 fields; `tz` is set
- [ ] `actions` has ≥1 entry
- [ ] Every `tool` is one of the five literals
- [ ] Every `channel_id` / `user_id` / `connection` resolves to something the user named in the interview
- [ ] Every `{{stepN.PATH}}` reference points at a step that produces that output
- [ ] **For each `http_request` template ref: I have curled the endpoint and confirmed `PATH` resolves to a real value (Step 3.5). Skipping = empty placeholders in production.**
- [ ] `name` is ≤80 chars, human-readable
- [ ] `sender_kind` is set; `coworker_id` is present iff `sender_kind="coworker"`
- [ ] No `SELECT *` to a public channel without `LIMIT`
- [ ] No sensitive-column patterns in SQL queries

## After submission

```bash
# Verify
ano automation list --agent

# Test (dry-run)
ano automation run auto_abc --agent

# Fire for real once
ano automation run auto_abc --no-dry-run --agent
```

User enables it in the Ano UI — deliberate human gate so an automation never silently starts firing.
