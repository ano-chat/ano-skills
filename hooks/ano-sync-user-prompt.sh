#!/usr/bin/env bash
#
# Ano Sync — Claude Code "UserPromptSubmit" hook (bundled by the ano-skills plugin).
#
# Fires on each new user turn. For repos opted into Ano Sync, it reminds the
# agent to RE-CHECK the channel (not just at session start) so it picks up the
# other agents' latest decisions and open `work_started` claims before doing
# overlapping work. Zero setup — bundled with the plugin; silent elsewhere.

set -euo pipefail

# Opt-in gate (same as the other hooks): only act for repos using Ano Sync.
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

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"[Ano Sync] If this turn involves implementation/edits in this repo, FIRST re-check the channel with ano_get_channel_context (a teammate's agent may have posted new decisions, blockers, or claims since you last looked). Respect open work_started claims: if another actor has an open work_started on the area you're about to touch (no later completed/failed on it), coordinate or pick a different area instead of editing it. Skip this re-check for pure discussion turns with no edits."}}
JSON
