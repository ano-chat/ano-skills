# Ano Skills

Claude Code skills for [Ano](https://ano.chat).

Ano is team chat with Claude Code and agents built in. These skills teach Claude Code how to work with Ano: use the `ano` CLI, read workspace context, send messages, and understand payloads sent from the Ano desktop app.

## Install

```bash
claude plugin install @ano-chat/skills
```

## What Is Included

Nine focused, self-contained skills. Each loads only when its trigger phrases match — so a "send a message" prompt no longer pulls the full CLI surface into context.

| Skill               | Domain                                                                                 |
| ------------------- | -------------------------------------------------------------------------------------- |
| `ano-core`          | Foundational rules — auth, output modes, exit codes, rate limits, triggered-auth flow. |
| `ano-messages`      | Send/read/reply/search messages, DMs, group DMs, file attachments, screenshots.        |
| `ano-channels`      | List/admin channels + workspaces + members, send invites.                              |
| `ano-coworkers`     | Create / update / test AI teammates (managed or external-webhook).                     |
| `ano-notifications` | DND quiet hours, notification level, email/desktop/mobile push toggles.                |
| `ano-tables`        | List/query/write Ano tables (structured rows / lists / databases).                     |
| `ano-automations`   | Build-Before-Talk methodology, 5 trigger types, 5 action tools, third-party OAuth.     |
| `ano-realtime`      | `ano connect` SSE bridge, OpenClaw agent forwarding, install-as-service.               |
| `ano-payloads`      | Parse `<ano_payload>` XML blocks from the Ano desktop's Send-to-Shell gesture.         |

### Trigger ownership rules (for future skill edits)

- Verb-led triggers (send/read/search/post/reply/dm/share) → `ano-messages`
- Object-led naming channels/workspaces/members/invites → `ano-channels`
- Object-led naming coworkers/teammates → `ano-coworkers`
- Object-led naming dnd/notification/push/email → `ano-notifications`
- Object-led naming tables/rows → `ano-tables`
- Object-led naming automations/triggers/jobs/webhooks/integrations → `ano-automations`
- Object-led naming bridge/stream/connect → `ano-realtime`
- Foundational (use ano / ano version / authenticate / smoke / doctor) → `ano-core`

Resolve overlap on the more-specific term. "Send a webhook" → `ano-automations` (webhook = automation noun), not `ano-messages`.

## Use It

Install the Ano CLI. Two paths — pick whichever fits your setup:

```bash
# Native binary (recommended — ~20ms cold start, no Node required)
curl -fsSL https://raw.githubusercontent.com/ano-chat/ano-cli/main/scripts/install.sh | bash

# npm (works everywhere Node 20+ runs, including Windows)
npm install -g @ano-chat/cli
```

Sign in:

```bash
ano auth login
```

Then ask Claude Code to work with Ano, for example:

```text
Read the latest messages in #general.
Send a DM to Jane.
Search Ano for the staging error thread.
```

## Links

- Website: [ano.chat](https://ano.chat)
- CLI package: [`@ano-chat/cli`](https://www.npmjs.com/package/@ano-chat/cli)
- Skills package: [`@ano-chat/skills`](https://www.npmjs.com/package/@ano-chat/skills)
