---
name: ano-coworkers
description: |
  Create, update, and test AI teammates ("coworkers") via the `ano` CLI.
  Covers managed (Anthropic-hosted) and external (own webhook) coworkers,
  capability scoping, and webhook reachability tests. Self-contained.
triggers:
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
invocable: true
argument-hint: "[command] [args...]"
---

# Ano CLI — Coworkers (AI teammates)

## Essentials

- Output: `--agent` for raw JSON, `--json` for envelope. Never parse styled TTY.
- IDs are UUIDs — never fabricate. `ano users list --agent` resolves channel/user names.
- Exit codes: 0 OK · 1 USAGE · 2 NOT_FOUND · 3 AUTH · 4 FORBIDDEN · 5 RATE_LIMIT.
- On exit 3 (AUTH), orchestrate the triggered-auth flow inline.
- **Never expose API keys.** Coworker create returns `api_key` + `webhook_secret` ONCE — relay to the user for storage, do NOT log to scrollback.

## Decision tree

```
Need an AI teammate?
├── Managed (Anthropic-hosted, no infra)
│   → ano coworker create "Display Name" --role-title "..." --agent
├── External (your own webhook endpoint, full control)
│   → ano coworker create "Display Name" --role-title "..." \
│       --external --webhook-url https://your.host/webhook --agent
│   ⚠ Response includes api_key + webhook_secret ONCE — save NOW, not recoverable.
├── Test the webhook is reachable
│   → ano coworker webhook-test <coworker-id> --agent
├── Edit an existing coworker
│   → ano coworker update <coworker-id> [--field value …] --agent
│      ⚠ Only fields you pass are changed; everything else is left alone.
│      Toggling --enabled true/false sends an "Agent paused/resumed" DM.
├── Add to channels at create time          → --channels ch1,ch2,ch3
├── Limit to specific capabilities          → --capabilities send_message,read_table
└── Set persona / expertise / boundaries    → --expertise "..." --personality "..." --boundaries "..."
```

Pick **managed** unless the user has an existing service to call out to (CRM, their own LLM, a Linear bot). Managed is the default and simpler.

## Quick reference

| Task                     | Command                                                                                                                            |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| Create managed coworker  | `ano coworker create "Display Name" --role-title "Role" --agent`                                                                   |
| Create external coworker | `ano coworker create "Display Name" --role-title "Role" --external --webhook-url <url> --agent`                                    |
| Update coworker          | `ano coworker update <coworker-id> [--display-name …] [--role-title …] [--custom-instructions …] [--enabled true/false] … --agent` |
| Test outbound webhook    | `ano coworker webhook-test <coworker-id> --agent`                                                                                  |

## Workflows

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
# No webhook needed. Coworker shows up in users list immediately.
```

### Create an external coworker (own webhook)

```bash
ano coworker create "Linear-Bot" \
  --role-title "Linear ops" \
  --external \
  --webhook-url https://bots.example.com/linear/webhook \
  --agent
# ⚠ Save api_key + webhook_secret from the response NOW.
# Returned ONCE; not recoverable later.

# Verify the endpoint is reachable:
ano coworker webhook-test "$COWORKER_ID" --agent
```

### Pause / resume a coworker

```bash
ano coworker update <coworker-id> --enabled false --agent  # sends "Agent paused" DM
ano coworker update <coworker-id> --enabled true --agent   # sends "Agent resumed" DM
```

## Edge cases

- **Partial update**: `coworker update` only changes fields you pass. Everything else preserved.
- **External coworker secrets**: `api_key` + `webhook_secret` returned ONCE on create. No recovery — re-create the coworker if lost.
- **`--channels`**: only at create time. Add to additional channels later via `ano channels member-add` (see ano-channels).
- **`--capabilities`**: restricts the tools the coworker can invoke. Default is broad; narrow for least-privilege.
- **`webhook-test`** sends a synthetic ping to the configured webhook-url and returns latency + response code. Use after create to confirm reachability.
