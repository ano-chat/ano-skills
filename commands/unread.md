---
allowed-tools: Bash(ano channels list:*), Bash(ano messages read:*), Bash(jq:*)
description: Triage unread Ano channels — pre-runs the unread+read sequence and asks Claude to summarise each
---

## Unread channels (output of `ano channels list --unread --agent`)

!`ano channels list --unread --agent`

## Recent history per unread channel (up to 100 messages each)

The bash below tags every message with a pre-built `JUMP:` URL line BEFORE
its content. URLs use the `ano://` protocol scheme so they route in-app
regardless of whether the user is on dev:local, staging, or prod (the
Ano desktop app registers itself as the system handler for `ano://`).
To deep-link to a message, take its `JUMP:` URL and wrap it in a
Markdown link as `[Jump to message](<that-url>)`.

!`ids=$(ano channels list --unread --agent | jq -r '.id'); if [ -z "$ids" ]; then echo "(no unread channels)"; else for ch in $ids; do echo "=== CHANNEL $ch ==="; ano messages read --channel "$ch" --limit 100 --agent | jq -r --arg ch "$ch" '"JUMP: ano://channel/\($ch)?message=\(.id)\n" + (. | tostring)'; done; fi`

## Your task

If the first section returned no rows (or the second section says
`(no unread channels)`), respond with a short "you're caught up" and
stop.

Otherwise, summarise each unread channel. For each:

- **Headline**: name the topic, the people driving it, and what's
  pending. Reflect what's really there — never pre-write the summary.
- **Decision-shaped message**: pick the most decision-shaped message in
  the channel — a wrap-up ("wrapping up", "to recap", "summary of",
  embedded scenario lists, prototype URLs, explicit asks for sign-off)
  wins; otherwise the most recent. End the channel's summary with a
  Markdown deep-link to it:

  `[Jump to message](ano://channel/<channel_id>?message=<message_id>)`

  The `JUMP:` line preceding each message in the second section has the
  URL pre-built — just wrap it in Markdown.

- **Multiple channels**: lead with the freshest, mention the others.
  Under three channels → summarise each; more → summarise the top one
  and list the rest as headlines.

Channels returned by `--unread` are the ONLY channels you summarise.
Don't iterate other channels "for completeness" — they have nothing new
for the user by definition.

The Markdown deep-link is mandatory, not optional. Without it the
summary is dead-end text.
