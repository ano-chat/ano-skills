#!/usr/bin/env bash
#
# Ano Sync — Claude Code "Stop" hook (bundled by the ano-skills plugin).
#
# When a turn ends, if THIS repo is opted into Ano Sync AND files changed, it
# blocks the stop and tells the agent to post one Ano Sync update via the
# ano_send_sync_event MCP tool before finishing — rich, agent-authored, no API
# key (posts through the "ano" MCP server this plugin also provides).
#
# OPT-IN by design: silent unless the repo has an Ano Sync channel configured,
# so installing the plugin never nudges users who aren't using Ano Sync.
# Works wherever Claude Code runs — iTerm2, Cursor's terminal, etc.

set -euo pipefail
input="$(cat)"

# Loop guard: if this Stop is already a continuation from this hook, let it stop.
compact="$(printf '%s' "$input" | tr -d '[:space:]')"
case "$compact" in
  *'"stop_hook_active":true'*) exit 0 ;;
esac

# Opt-in gate: act only when this repo is set up for Ano Sync — an
# ANO_SYNC_CHANNEL env var, or an "Ano Sync" section in CLAUDE.md / AGENTS.md.
# Otherwise stay completely silent.
opted_in=0
[ -n "${ANO_SYNC_CHANNEL:-}" ] && opted_in=1
if [ "$opted_in" = "0" ]; then
  for f in CLAUDE.md .claude/CLAUDE.md AGENTS.md; do
    if [ -f "$f" ] && grep -qi "ano sync" "$f" 2>/dev/null; then
      opted_in=1
      break
    fi
  done
fi
[ "$opted_in" = "1" ] || exit 0

# Only nudge when real work happened — working-tree changes in this repo.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
[ -n "$(git status --porcelain 2>/dev/null)" ] || exit 0

# Already posted this turn? Stay silent. If a Sync Event was posted since the
# last real user prompt (the skill usually posts mid-turn), this hook would
# otherwise fire a redundant nudge. Read the transcript and skip if it's covered
# — this keeps the hook a true backstop, not a second prompt.
tp="$(printf '%s' "$input" | sed -n 's/.*"transcript_path":[[:space:]]*"\([^"]*\)".*/\1/p')"
if [ -n "$tp" ] && [ -f "$tp" ]; then
  lp="$(grep -nE '"(type|role)":[[:space:]]*"user"' "$tp" 2>/dev/null | grep -v 'tool_result' | tail -1 | cut -d: -f1)"
  if [ -n "$lp" ] && tail -n "+$lp" "$tp" 2>/dev/null | grep -q 'ano_send_sync_event'; then
    exit 0
  fi
fi

# Block the stop + instruct the agent to post exactly one Sync Event.
cat <<'JSON'
{"decision":"block","reason":"Before you stop, post one Ano Sync update for the work you just did. Call the ano_send_sync_event MCP tool for THIS repo's Ano channel (the channel (a name like #ano-sync-demo, or an id) is in CLAUDE.md under 'Ano Sync' or the ANO_SYNC_CHANNEL env var; if it is a name, resolve it to the channel_id with list_channels (within the current workspace); if unclear, ask once and remember it). Pick the eventType that fits (progress | completed | blocker | tests | review_requested), set a short title + one-line summary, and include changedFiles, decisions, risks, and nextSteps where they apply. Post exactly ONE concise card — do not repeat one you already posted this turn — then stop."}
JSON
