---
name: ano-channels
description: |
  Channel + workspace administration via the `ano` CLI — list channels,
  list workspaces + members, archive a channel, add/remove channel + workspace
  members, send invites. Also covers the unread-triage "what did I miss?"
  surface via `ano channels list --unread`. Self-contained. Does NOT cover
  messaging (see ano-messages) or coworker creation (see ano-coworkers).
triggers:
  - list channels
  - show channels
  - list users
  - list members
  - list workspaces
  - archive channel
  - archive a channel
  - add to channel
  - add member to channel
  - remove from channel
  - kick from channel
  - add to workspace
  - add member to workspace
  - remove from workspace
  - kick from workspace
  - workspace member
  - promote to member
  - invite teammate
  - invite member
  - send invite
  - what did i miss
  - anything new
  - catch me up
  - unread
  - unread channels
invocable: true
argument-hint: "[command] [args...]"
---

# Ano CLI — Channels & Workspaces (admin)

## Essentials

- Output: `--agent` for raw JSON, `--json` for envelope. Never parse styled TTY.
- IDs are UUIDs — never fabricate. `ano channels list --agent` and `ano users list --agent` are the lookups.
- Exit codes: 0 OK · 1 USAGE · 2 NOT_FOUND · 3 AUTH · 4 FORBIDDEN · 5 RATE_LIMIT.
- On exit 3 (AUTH), orchestrate the triggered-auth flow inline.
- 60 req/min sliding window; CLI auto-retries 429.

## Decision tree

```
Listing or inspecting?
├── Which channels exist?         → ano channels list --agent
├── Who's in the workspace?       → ano users list --agent
└── Multiple workspaces?          → ano workspaces list --agent

Managing a channel?
├── Archive (irreversible-ish)    → ano channels archive <channel-id> --agent
├── Add a teammate                → ano channels member-add <channel-id> --user <user-id> --agent
├── Remove a teammate             → ano channels member-remove <channel-id> --user <user-id> --agent
└── Need the user-id?             → ano users list --agent  (by display name or email)

Managing workspace membership?
├── Add a member (or rejoin)      → ano workspaces member-add <workspace-id> <user-id> --agent
├── Remove a member (soft-delete) → ano workspaces member-remove <workspace-id> <user-id> --agent
├── Need the user-id?             → ano user_get_by_email "alice@acme.com" --agent
└── List members                  → ano users list --agent

Inviting someone NOT yet in the workspace?
├── By email                      → ano invite alice@example.com --expires-hours 72
└── Open invite (no email)        → ano invite --expires-hours 72
```

## Quick reference

| Task                     | Command                                                                  |
| ------------------------ | ------------------------------------------------------------------------ |
| List channels            | `ano channels list --agent`                                              |
| Unread channels (triage) | `ano channels list --unread --agent`                                     |
| Create channel           | `ano channels create <name> [--private] [--topic ...] [--members u1,u2]` |
| List users               | `ano users list --agent`                                                 |
| List workspaces          | `ano workspaces list --agent`                                            |
| Set active workspace     | `ano workspaces use <workspace-id>`                                      |
| Archive channel          | `ano channels archive <channel-id> --agent`                              |
| Add channel member       | `ano channels member-add <channel-id> --user <user-id> --agent`          |
| Remove channel member    | `ano channels member-remove <channel-id> --user <user-id> --agent`       |
| Add workspace member     | `ano workspaces member-add <workspace-id> <user-id> --agent`             |
| Remove workspace member  | `ano workspaces member-remove <workspace-id> <user-id> --agent`          |
| Invite teammate by email | `ano invite <email> [--expires-hours N]`                                 |
| Open invite (no email)   | `ano invite [--expires-hours N]`                                         |

## Workflows

### "What did I miss?" — unread triage

When the user asks an open question like "what did I miss?" / "anything
new?" / "catch me up", do NOT ask which channel — discover it.

**Prefer the pre-baked `/unread` slash command if your runtime can
invoke one programmatically.** The command (at `commands/unread.md`
in this plugin) bundles the unread-discovery + per-channel-history
fetch into one shot. On Claude Code specifically, slash commands are
invoked via the `Skill` tool — when the user types `/<name>` the
runtime maps it to `Skill(skill: "<name>", ...)`, and you can call
the same tool yourself for natural-language triggers using the exact
slug from your available-skills system reminder (typically
`ano-skills:unread`, or `unread` if unprefixed). Other runtimes may
expose slash commands differently, or not at all — fall back to the
bash recipe below in that case.

**Manual fallback** (whenever you can't reach the slash command —
different runtime, slug not listed, or no slash-command infrastructure
at all):

```bash
# Single bash one-liner — same recipe `/unread` bakes in. The `JUMP:`
# prefix line before each message gives you the pre-built deep-link URL;
# wrap it in Markdown `[Jump to message](...)` when you emit the summary.
# The base comes from `ano web-url` — the deployed web app for the current
# environment (app.ano.dev / app-staging.ano.dev / localhost:1420 in dev).
# It's a normal web URL: clicked in the Ano in-app shell it opens the
# channel in-app; clicked in any other terminal it opens the web app.
BASE=$(ano web-url 2>/dev/null || echo "http://localhost:1420")
ids=$(ano channels list --unread --agent | jq -r '.id')
if [ -z "$ids" ]; then
  echo "(no unread channels)"
else
  for ch in $ids; do
    echo "=== CHANNEL $ch ==="
    ano messages read --channel "$ch" --limit 100 --agent | \
      jq -r --arg ch "$ch" --arg base "$BASE" '"JUMP: \($base)/?channel=\($ch)&message=\(.id)\n" + (. | tostring)'
  done
fi
```

If the unread list is empty, say "you're caught up" and stop.

**Rules for the summary itself (apply to both paths):**

- Summarise from actual message content — name the topic, the people
  driving it, what's pending. NEVER pre-write the summary; reflect
  what's really there.
- Channels returned by `--unread` are the ONLY channels you summarise.
  Don't iterate other channels "for completeness" — they have nothing
  new for this user by definition.
- Multiple channels unread: lead with the freshest, mention the others.
  Under three channels → summarise each; more → summarise the top one
  and list the rest as headlines.
- **MANDATORY** — every channel summary ends with a Markdown deep-link
  to the most decision-shaped message in that channel:
  `[Jump to message](<web-url>/?channel=<channel_id>&message=<message_id>)`
  (base from `ano web-url`; the `JUMP:` line has the full URL pre-built).
  Pick by content: a wrap-up message ("wrapping up", "to recap",
  "summary of options", scenario lists, embedded prototype URLs,
  explicit asks for sign-off) wins; otherwise the most recent. Do not
  phrase as "see message <id>" — emit the Markdown link. Without it
  the summary is dead-end text.

### Archive an old channel

```bash
channels=$(ano channels list --agent)
# Extract CHANNEL_ID for "old-project"
ano channels archive "$CHANNEL_ID" --agent
# Archived channels disappear from sidebars; messages are preserved.
```

### Add a teammate to a channel

```bash
users=$(ano users list --agent)
# Find USER_ID by display name or email
ano channels member-add "$CHANNEL_ID" --user "$USER_ID" --agent
# Idempotent: already-a-member returns 200, doesn't error.
# Rejects: archived channel (400), DM/space target (400), non-workspace member (404).
```

### Invite a teammate

```bash
ano invite alice@example.com --expires-hours 72
# Returns { token, invite_url, expires_at } — share invite_url with Alice.
# Re-running with the same email revokes the previous token first.
```

## Edge cases

- **Channel archive**: caller must be a workspace admin (or the channel creator).
- **Channel `member-add`** is idempotent. Rejects archived channels, non-channel types (DMs, spaces), and non-workspace users with 400/404 — no opaque 500s.
- **Channel `member-remove`** is a soft-delete (`removed_at` tombstone). Re-addable later; history preserved.
- **Workspace `member-add`** is idempotent — rejoins removed members (clears `removed_at`), promotes `collaborator` → `member`, no-op if already a full member. Auto-joins public channels in the same transaction.
- **Workspace `member-remove`** is a soft-delete. Forbidden against the workspace's `primary_owner` — transfer ownership through the desktop UI first.
- **Self-removal is blocked** server-side; the "leave workspace" flow has a different audit trail (no `removed_by`). Use the desktop UI.
- **Invite re-issue**: same email → previous token revoked, new one returned.
