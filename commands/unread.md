---
allowed-tools: Bash(ano web-url:*), Bash(ano channels list:*), Bash(ano messages read:*), Bash(jq:*)
description: Triage unread Ano channels — pre-runs the unread+read sequence and asks Claude to summarise each
---

## Unread channels (output of `ano channels list --unread --agent`)

!`ano channels list --unread --agent`

## Recent history per unread channel (up to 100 messages each)

The bash below tags every message with a pre-built `JUMP:` URL line BEFORE
its content. The base comes from `ano web-url` (the deployed web app for
the current environment — `app.ano.dev`, `app-staging.ano.dev`, or
`localhost:1420` in dev), so the link is correct everywhere. It's a normal
web URL: clicked inside the Ano in-app shell it opens the channel in-app;
clicked in any other terminal it opens the web app in the browser.
To deep-link to a message, take its `JUMP:` URL and wrap it in a
Markdown link as `[Jump to message](<that-url>)`.

!`BASE=$(ano web-url 2>/dev/null || echo "http://localhost:1420"); ids=$(ano channels list --unread --agent | jq -r '.id'); if [ -z "$ids" ]; then echo "(no unread channels)"; else for ch in $ids; do echo "=== CHANNEL $ch ==="; ano messages read --channel "$ch" --limit 100 --agent | jq -r --arg ch "$ch" --arg base "$BASE" '"JUMP: \($base)/?channel=\($ch)&message=\(.id)\n" + (. | tostring)'; done; fi`

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

  `[Jump to message](<web-url>/?channel=<channel_id>&message=<message_id>)`

  The `JUMP:` line preceding each message in the second section has the
  full URL pre-built (base from `ano web-url`) — just wrap it in Markdown.

- **Multiple channels**: lead with the freshest, mention the others.
  Under three channels → summarise each; more → summarise the top one
  and list the rest as headlines.

Channels returned by `--unread` are the ONLY channels you summarise.
Don't iterate other channels "for completeness" — they have nothing new
for the user by definition.

The Markdown deep-link is mandatory, not optional. Without it the
summary is dead-end text.
