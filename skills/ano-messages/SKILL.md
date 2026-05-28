---
name: ano-messages
description: |
  Send/read/reply/search messages and DMs via the `ano` CLI. Covers channel
  posts, thread replies, @mentions, file attachments, screenshots, 1:1 DMs,
  group DMs (Slack-style MPIM), and search. Self-contained — does not load
  other ano-* skills.
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
  - notify team
  - notify channel
  - update the team
  - post an update
invocable: true
argument-hint: "[command] [args...]"
---

# Ano CLI — Messages & DMs

## Essentials

- Output: `--agent` for raw JSON, `--json` for envelope. Never parse styled TTY.
- IDs are UUIDs — never fabricate. One-shot name resolution via `--channel-name` and `--to` is preferred over list-then-act.
- Exit codes: 0 OK · 1 USAGE · 2 NOT_FOUND · 3 AUTH · 4 FORBIDDEN · 5 RATE_LIMIT · 6 NETWORK · 7 API.
- On exit 3 (AUTH), orchestrate the triggered-auth flow inline (not in scope here — see CLI docs).
- 60 req/min sliding window; CLI auto-retries 429.
- Content is markdown (bold, links, code blocks).

## Decision tree

```
Want to send something?
├── To a channel by name → ano messages send "text" --channel-name engineering --agent   ← preferred (1 round trip)
├── To a channel by id   → ano messages send "text" --channel <id> --agent               ← when ID known (e.g. from <ano_payload>)
├── Reply in thread      → add --thread <msg_id>
├── With @mention        → add --mention <user_id>
├── With file attached   → add --file ./path.png  (repeat for multiple; empty content OK)
├── DM someone           → ano dm send "text" --to "Name" --agent                        ← 1 round trip
└── DM multiple people   → ano dm send "text" --to Alice --to Bob --to Carol --agent     ← group DM

Want to find something?
├── Know the channel?  → ano messages read --channel <id> --limit 20 --agent
├── Need to search?    → ano messages search "query" --limit 5 --agent
└── Have a URL?        → ano show <url> --agent
```

## Quick reference

| Task                         | Command                                                                                                 |
| ---------------------------- | ------------------------------------------------------------------------------------------------------- |
| Send message (preferred)     | `ano messages send "text" --channel-name engineering --agent`                                           |
| Send message (by ID)         | `ano messages send "text" --channel <id> --agent`                                                       |
| Reply in thread              | `ano messages send "text" --channel <id> --thread <msg_id> --agent`                                     |
| Send with @mention           | `ano messages send "text" --channel-name engineering --mention <user_id> --agent`                       |
| Send DM (by name)            | `ano dm send "text" --to "Name" --agent`                                                                |
| Send DM (by email)           | `ano dm send "text" --email user@co.com --agent`                                                        |
| Send DM (by ID)              | `ano dm send "text" --user-id <id> --agent`                                                             |
| Group DM (names)             | `ano dm send "text" --to "Alice" --to "Bob" --agent` (CLI v2.17.0+)                                     |
| Group DM (comma form)        | `ano dm send "text" --to "Alice,Bob,Carol" --agent`                                                     |
| Group DM (mixed)             | `ano dm send "text" --to "Alice" --user-id <id> --agent`                                                |
| Attach file                  | `ano messages send "see screenshot" --channel-name engineering --file ./bug.png --agent` (CLI v2.18.0+) |
| Screenshot-only (no caption) | `ano messages send "" --channel-name design --file ./shot.png --agent`                                  |
| Multiple files               | `ano messages send "logs" -c <id> --file ./out.txt --file ./err.txt --agent`                            |
| DM with file                 | `ano dm send "fyi" --to "Alice" --file ./report.pdf --agent`                                            |
| Read messages                | `ano messages read --channel <id> --limit 10 --agent`                                                   |
| Search                       | `ano messages search "query" --limit 5 --agent`                                                         |
| Show URL content             | `ano show <url> --agent`                                                                                |

## Workflows

### Post in a known channel (preferred one-shot)

```bash
# Single call. Server resolves "engineering" → id atomically with the insert.
ano messages send "Here's my analysis..." --channel-name engineering --agent
```

### Read a channel and reply

```bash
channels=$(ano channels list --agent)
# Parse to find CHANNEL_ID for "general"
messages=$(ano messages read --channel "$CHANNEL_ID" --limit 20 --agent)
ano messages send "Here's my analysis..." --channel "$CHANNEL_ID" --agent
```

### Search, then reply in thread

```bash
results=$(ano messages search "deployment issue" --agent)
# Extract CHANNEL_ID and MSG_ID from results
ano messages send "Fix applied" --channel "$CHANNEL_ID" --thread "$MSG_ID" --agent
```

### DM with user lookup

```bash
users=$(ano users list --agent)
# Find USER_ID for "Jane"
ano dm send "Can you review PR #42?" --to "Jane" --agent
```

### Group DM (Slack-style MPIM, CLI v2.17.0+)

When the user says "DM Alice and Bob" or "let Alice, Bob, and Carol know …", reach for the multi-recipient form. The server finds-or-creates a single `group_dm` channel for that exact participant set and posts the message. Idempotent — same recipients always land in the same channel. Membership is immutable (Slack convention).

```bash
ano dm send "ship gate at 17:00 — please confirm" --to "Alice" --to "Bob" --to "Carol" --agent
ano dm send "ship gate at 17:00" --to "Alice,Bob,Carol" --agent
ano dm send "kick-off at 09:00" --to "Alice" --user-id usr_bob --agent
```

≥3 distinct members (you + ≥2 others). Single recipient → 1:1 DM. `--email` stays 1:1-only. Result JSON: `"channel_type": "group_dm"` and `"recipients": [...]`.

### Share a local file (CLI v2.18.0+)

`--file` works on both `messages send` and `dm send`. CLI uploads each file to R2 and posts message + attachment row in one server-side transaction. Empty content allowed when ≥1 `--file` present.

```bash
ano messages send "see screenshot for the bug repro" --channel-name engineering --file ./bug.png --agent
ano messages send "logs from the failing run" -c <id> --file ./out.txt --file ./err.txt --agent
ano messages send "" --channel-name design --file ./shot.png --agent
ano dm send "report attached" --to "Alice" --file ./report.pdf --agent
```

- Per-file cap: 25 MB. Per-invocation total: 125 MB (pre-flight).
- Types: images, video, audio, PDF, office docs, text, JSON, zip/tar/gz.
- Result includes `attachment_ids: [...]`.
- If the file is already at a known path, just `--file` directly — no copy-to-shared step needed.

### Extending a shared prototype — write a NEW file, attach it

When the user shares a file in chat (e.g. an `<ano_payload>` Send-to-Shell
block with an `<attachment url="...">` element) and asks you to extend it
— add a variant, write a new scenario, build on top — you MUST:

1. Write a NEW file (variant filename) — never overwrite the original.
   The shared file is the starting state; mutating it in place destroys
   the "before" of any future review.
2. Attach the new file via `--file` so the chat renders a clickable
   attachment chip (not an inline URL in the message body).

Where to write the variant: anywhere on disk you control (`/tmp/` is
fine). `--file` uploads through the standard pipeline — the source path
doesn't matter; the server stores the bytes and stamps a fresh
`storage_url` that the chat renders.

```bash
# 1. WebFetch the URL from the payload's <attachment url=...> — already
#    authoritative; don't search for the file.

# 2. Write the variant locally with a clearly-variant filename
#    (scenarios-v2.html, scenarios-scenario-c.html, etc.). Reuse the
#    original's structure; only your additions / changes differ.

# 3. `ano messages send` — IMPORTANT: put the content BEFORE `--file` so
#    Commander doesn't gobble it as a variadic file path.
ano messages send \
  "Scenario C is ready — progressive trust ladder. See the new tab." \
  --channel-name product-demo \
  --file "/tmp/scenarios-v2.html" \
  --agent
```

Rules:

- New file each time. Never overwrite the original.
- Always `--file <path>` — never an inline URL in the body. The inline
  URL is text; `--file` produces an attachment row that renders as a
  clickable chip.
- Content argument BEFORE `--file`. Otherwise the variadic `--file` eats
  the content and the CLI errors with `missing required argument
'content'`.

## Performance (CLI v2.25.0+)

The basic-text `messages send` path — `--channel <id>` with no `--thread`, `--mention`, `--file`, or `--channel-name` — now flows through an optimistic Zero mutator (~310 ms vs. ~700 ms REST). Server still runs the authoritative mutator (membership check, fan-out, notifications, embedding queue) in parallel. Any path that needs server-side resolution (channel-name lookup, attachment upload, thread parent denormalization, mention @handle → user_id) stays on REST. No caller-visible difference beyond latency.

## Edge cases

- Channel by name with `--channel-name <name>` is 1 round trip and atomic at the server. If the channel doesn't exist, returns exit 2 (NOT_FOUND); do NOT fall back to creating it silently.
- Threads: pass the parent message id as `--thread <id>`. Replying to a thread that doesn't exist returns exit 2.
- @mention: `--mention <user_id>` injects an at-mention into the rendered message. Use the user's UUID, not their display name.
- DM `--email` is 1:1-only. For group DMs, only `--to` (name or id list) works.
- `ano show <url>` fetches and renders linkable content (Notion, Linear, GitHub, etc.) for the agent to read.
