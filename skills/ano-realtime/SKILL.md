---
name: ano-realtime
description: |
  Real-time SSE bridge via `ano connect` — persistent stream of channel
  messages, DMs, thread replies, reactions, and channel-membership events.
  Covers OpenClaw agent bridging, install-as-service, and the stdin/stdout
  protocol. Self-contained.
triggers:
  - ano connect
  - real-time bridge
  - real time bridge
  - stream events
  - openclaw bridge
  - stdin/stdout bridge
  - bridge protocol
  - install bridge service
invocable: true
argument-hint: "[command] [args...]"
---

# Ano CLI — Real-time bridge

## Essentials

- Output: events stream as **one JSON object per line** on stdout. Don't parse styled output.
- Exit codes: 0 OK · 3 AUTH · 6 NETWORK. The bridge auto-reconnects on transient network errors.
- On exit 3 (AUTH), orchestrate the triggered-auth flow inline (see core skill).
- The bridge holds a long-lived connection — treat it as a long-running process, not a one-shot command. Use `--health-port` for liveness checks.

## Decision tree

```
Need real-time events from Ano?
├── One-shot interactive stream (your terminal)        → ano connect
├── Bridge events into an agent runtime                → ano connect --openclaw <url>
├── Add a health endpoint                              → ano connect --health-port 8080
├── Install as a persistent OS service                 → ano connect install-service --key ano_cwk_... [--openclaw <url>] [--health-port <port>]
└── Remove a previously installed service              → ano connect uninstall-service --service-name <name-or-hash>
```

## Quick reference

| Task                    | Command                                                                             |
| ----------------------- | ----------------------------------------------------------------------------------- |
| Start SSE bridge        | `ano connect`                                                                       |
| Bridge + OpenClaw agent | `ano connect --openclaw <url>`                                                      |
| Bridge + health server  | `ano connect --health-port 8080`                                                    |
| Install service         | `ano connect install-service --key ano_cwk_... --openclaw <url> --health-port 8080` |
| Remove service          | `ano connect uninstall-service --service-name <name-or-hash>`                       |

## Event types

| Type              | Trigger         | Key fields                                 |
| ----------------- | --------------- | ------------------------------------------ |
| `connected`       | Stream open     | workspace, channels, members               |
| `message`         | Channel message | channel_id, content, sender_name, mentions |
| `thread_reply`    | Thread reply    | channel_id, thread_id, content, parent     |
| `dm`              | Direct message  | channel_id, content, sender_name           |
| `reaction`        | Emoji reaction  | message_id, emoji, sender_name             |
| `channel_added`   | Joined channel  | channel_id, user_id                        |
| `channel_removed` | Left channel    | channel_id, user_id                        |

Agent mode (`--openclaw <url>`) auto-responds to DMs, thread replies, and @mentions.

## stdin/stdout protocol

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

## Workflows

### Persistent agent bridge with OpenClaw

```bash
# Install as an OS-managed service so it auto-starts and auto-restarts.
ano connect install-service \
  --key ano_cwk_... \
  --openclaw http://localhost:3000 \
  --health-port 8080

# Verify
curl http://127.0.0.1:8080/healthz
```

### One-off foreground stream (debug)

```bash
ano connect            # foreground, prints events to stdout, Ctrl+C to stop
ano connect --openclaw http://localhost:3000   # plus auto-respond via OpenClaw
```

## Edge cases

- **Service name on uninstall**: `--service-name` can be either the human-readable name OR the hash. The hash form is robust against display-name churn.
- **`--health-port`** is optional. When set, the bridge exposes `/healthz` returning 200 + a small JSON payload (`{ok, uptime, last_event_at}`) — useful for OS-level service supervisors.
- **`--openclaw <url>`**: the bridge forwards each event as a POST to `<url>`. Agent mode is enabled implicitly when this flag is set.
- **Reconnect behaviour**: the bridge handles transient network drops automatically with exponential backoff. Only exit code 3 (AUTH) or 6 (NETWORK after max retries) terminates the process.
- **Auth-key persistence**: `install-service --key ...` writes the key into the service's environment file. Rotate the key with `uninstall-service` + `install-service` again.
