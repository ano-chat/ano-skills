---
name: ano-notifications
description: |
  Do Not Disturb (quiet hours) and notification preferences via the `ano`
  CLI — set/clear DND windows, change notification level, toggle email
  digests, desktop/mobile push. Self-contained.
triggers:
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
invocable: true
argument-hint: "[command] [args...]"
---

# Ano CLI — DND & Notifications

## Essentials

- Output: `--agent` for raw JSON, `--json` for envelope. Never parse styled TTY.
- Exit codes: 0 OK · 1 USAGE · 3 AUTH · 5 RATE_LIMIT.
- On exit 3 (AUTH), orchestrate the triggered-auth flow inline.
- `prefs-set` is a **partial update** — only flags you pass change. Other fields preserved via `COALESCE`. Toggling email won't reset DND/push.

## Decision tree

```
Adjusting how/when the user gets pinged?
├── Quiet hours (DND)
│   ├── Set window     → ano dnd set --start 22:00 --end 07:00 --agent
│   ├── Clear          → ano dnd set --clear --agent
│   └── Times are workspace-local (24h HH:MM); window may cross midnight.
├── Notification level (per-workspace)
│   ├── Everything           → ano notifications prefs-set --global-level everything --agent
│   ├── Mentions + DMs only  → ano notifications prefs-set --global-level mentions_dms --agent
│   └── Nothing              → ano notifications prefs-set --global-level nothing --agent
├── Email digests
│   ├── Disable        → ano notifications prefs-set --no-email --agent
│   ├── Enable + delay → ano notifications prefs-set --email --email-delay-minutes 5 --agent
└── Desktop / mobile push toggles
    ├── ano notifications prefs-set --no-desktop --agent
    └── ano notifications prefs-set --no-mobile --agent
```

## Workflows

### Set DND quiet hours

```bash
# Block notifications 10pm–7am workspace-local.
ano dnd set --start 22:00 --end 07:00 --agent

# Clear when on call:
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
```

## Edge cases

- **Partial update**: `prefs-set` flags compose. Calling `--no-email` won't touch DND, push, or notification-level state.
- **DND window crossing midnight**: `--start 22:00 --end 07:00` is valid; the engine handles wrap-around.
- **Workspace-local times**: HH:MM is interpreted in the workspace's timezone. If the user is in a different tz than the workspace, surface that.
- **Levels are per-workspace**: setting `mentions_dms` in one workspace doesn't affect others. To replicate across workspaces, set the active workspace first (see `ano workspaces use`) and re-run.
