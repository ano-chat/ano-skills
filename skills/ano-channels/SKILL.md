---
name: ano-channels
description: |
  Channel + workspace administration via the `ano` CLI — list channels,
  list workspaces + members, archive a channel, add/remove channel + workspace
  members, send invites. Self-contained. Does NOT cover messaging (see
  ano-messages) or coworker creation (see ano-coworkers).
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
