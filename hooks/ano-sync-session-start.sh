#!/usr/bin/env bash
#
# Ano Sync — Claude Code "SessionStart" hook (bundled by the ano-skills plugin).
#
# For repos opted into Ano Sync, injects an instruction at session start so the
# agent automatically reads the channel's current state (via ano_get_channel_context)
# before doing any work — no manual prompting. Silent for every other repo.

set -euo pipefail

# Opt-in gate (same as the Stop hook): only inject for repos using Ano Sync.
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
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"This repo uses Ano Sync. Before your first action, call the ano_get_channel_context MCP tool for this repo's Ano channel (the channel — a name like #ano-sync-demo, or an id — is in CLAUDE.md under 'Ano Sync' or the ANO_SYNC_CHANNEL env var; resolve a name to its channel_id with list_channels first) to load current decisions, open risks/blockers/questions, changed files, and next steps. Don't redo work already done, and honor prior decisions."}}
JSON
