---
name: ano-sync
description: |
  Keep an Ano channel current as a "control tower" for your work — read the
  channel's state before you start and post structured Sync Events at
  milestones, automatically, via the `ano` MCP tools. Load this whenever work
  is being tracked in an Ano channel. The plugin's Stop hook also reminds you
  to post at the end of a turn that changed files. Self-contained.
triggers:
  - ano sync
  - sync event
  - control tower
  - post a sync update
  - read channel context
  - keep the team updated in ano
---

# Ano Sync

Ano Sync turns an Ano channel into a live record of your work so teammates (and
their agents) keep up without asking. You drive it with two MCP tools on the
**`ano`** server (provided by this plugin — no API key needed; you act as the
authenticated user):

- **`ano_get_channel_context(channel_id, message_limit?, event_limit?)`** —
  read the channel's current state: recent messages, recent Sync Events, and the
  derived decisions / open risks / blockers / open questions / changed files /
  next steps / agents involved / latest test status.
- **`ano_send_sync_event(channel_id, source, actorName, eventType, status,
title, summary?, changedFiles?, commandsRun?, tests?, decisions?, risks?,
blockers?, nextSteps?, links?)`** — post a structured Sync Event that renders
  as a card in the channel timeline and feeds the Control Tower panel.
  - `source`: `claude_code` (or `cursor`, `codex`, `terminal`, …).
  - `actorName`: who's working, e.g. `"Claude Code (Ruben)"`.
  - `eventType`: `work_started | progress | decision | blocker | question |
tests | review_requested | completed | failed`.
  - `status`: `info | success | warning | error`.

## Which channel?

The channel can be given as a **name** (e.g. `#ano-sync-demo`) or an id — use
whichever the human gives you; names are friendlier. The Sync tools take a
`channel_id`, so if you only have a name, resolve it first with `list_channels`
(match within the current workspace) and remember the id for the session.

Find the channel for the current work, in this order:

1. A channel the user named for this task (name or id).
2. A `## Ano Sync` block in the repo's `CLAUDE.md` (e.g. `channel: #ano-sync-demo`).
3. Otherwise ask the user once.

If no channel is in scope, do nothing — never invent one.

## When to READ — at the start of a task

Before planning a tracked task, call `ano_get_channel_context` **once**. Use it
to avoid redoing work, honor prior decisions, and pick up open blockers /
questions / next steps. Don't announce it; just use what you learn.

## When to POST — at milestones (never every turn)

Author and post a Sync Event yourself — you know the semantics — at real
milestones:

- starting a meaningful unit of work → `work_started`
- a notable chunk done / files changed → `progress` (or `completed` when the
  task is finished)
- a decision worth recording → `decision`
- blocked / a risk surfaced → `blocker` (with `blockers`) / include `risks`
- tests run → `tests` (with the `tests` array)
- ready for human review → `review_requested` (with `nextSteps`)

Include `changedFiles`, `decisions`, `risks`, `nextSteps`, etc. when they apply.
Keep each card concise.

### Anti-spam (important)

- Post at **milestones**, not on every chat turn or every file edit.
- Before posting, if you already posted a Sync Event for this same milestone
  this turn, **skip** — never double-post.
- For trivial Q&A turns with no real change, don't post.

## Coordinating with other agents (claims)

Teammates' agents may share this channel. Use a light "claim" convention so you
don't collide on the same code:

- **Respect open claims.** An open `work_started` by _another_ actor — a
  `work_started` naming an area with no later `completed`/`failed` on that area
  by the same actor — means that area is taken. Don't edit it; pick another area
  or coordinate (post a `question`/`blocker`, or work elsewhere).
- **Claim your area first.** Before editing a module, post a `work_started`
  whose `title` names the area (e.g. "Working on: auth module") and whose
  `changedFiles` lists the paths you intend to touch. That's your claim.
- **Release when done.** Post `completed` (or `failed`) for that area so others
  know it's free.
- **Re-check before overlapping work.** Your context can go stale mid-session;
  re-read (the UserPromptSubmit hook reminds you) before editing a shared area.

Cooperative, not enforced (git still arbitrates real conflicts) — but it keeps
two agents from unknowingly working the same code.

## Automatic backstop

This plugin installs Claude Code hooks so this stays hands-free:

- **SessionStart** — read the channel context at session start.
- **UserPromptSubmit** — re-check for new decisions/claims before overlapping
  work on a turn.
- **Stop** — if a turn ends with changed files and you haven't already posted a
  Sync Event this turn, post one before stopping.

Honor them: read at the start, respect others' claims, post one concise card per
milestone, then stop.
