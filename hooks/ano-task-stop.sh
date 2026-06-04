#!/usr/bin/env bash
#
# Ano Task — Claude Code "Stop" hook (bundled by the ano-skills plugin).
#
# Surfaces the result of a fire-and-forget background task dispatched via
# `ano task "<prompt>"`. The CLI runner writes one JSON file per task to
# $HOME/.cache/ano/tasks/<id>.json; when a turn ends, this hook scans for
# the oldest finished-but-unsurfaced task, marks it surfaced, blocks the
# stop, and tells the agent to relay the result to the user verbatim.
#
# SHARED CONTRACT (kept in lockstep with ano-cli's src/core/task-store.ts):
#   { id, prompt, target, status: queued|running|done|failed,
#     result, error, surfaced, created_at, started_at, completed_at }
#
# Robust by construction: every failure path exits 0 so a normal stop is
# never blocked. Silent when there are no finished tasks to surface.

set -euo pipefail
input="$(cat)"

# Loop guard: if this Stop is already a continuation from a hook, let it stop.
compact="$(printf '%s' "$input" | tr -d '[:space:]')"
case "$compact" in
  *'"stop_hook_active":true'*) exit 0 ;;
esac

dir="${HOME}/.cache/ano/tasks"
[ -d "$dir" ] || exit 0

# JSON parsing requires python3 — bail silently if it's not available.
command -v python3 >/dev/null 2>&1 || exit 0

# Find the oldest done/failed task with surfaced != true, mark it surfaced
# (write back), and print one tab-separated line: id<TAB>note<TAB>body.
# Any exception inside → exit 0 (empty output) so a normal stop proceeds.
picked="$(
  TASKS_DIR="$dir" python3 - <<'PY' 2>/dev/null || true
import glob, json, os, sys

tasks_dir = os.environ["TASKS_DIR"]
candidates = []
for path in glob.glob(os.path.join(tasks_dir, "*.json")):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            task = json.load(fh)
    except Exception:
        continue
    if not isinstance(task, dict):
        continue
    if task.get("status") not in ("done", "failed"):
        continue
    if task.get("surfaced") is True:
        continue
    candidates.append((task.get("created_at") or 0, path, task))

if not candidates:
    sys.exit(0)

# Oldest-first by created_at so results surface in dispatch order.
candidates.sort(key=lambda c: c[0])
_, path, task = candidates[0]

task["surfaced"] = True
try:
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(task, fh, indent=2)
except Exception:
    # Couldn't claim it — don't surface (avoids a relay loop on a read-only fs).
    sys.exit(0)

task_id = str(task.get("id") or "unknown")
status = task.get("status")
target = task.get("target")
note = ""
if status == "done" and target:
    note = " and posted it to " + str(target)

if status == "failed":
    body = task.get("error") or task.get("result") or "(the task failed with no detail)"
else:
    body = task.get("result") or "(the task produced no output)"

# Tab-separated; body newlines escaped so the line stays single-record.
body = str(body).replace("\\", "\\\\").replace("\t", " ").replace("\n", "\\n")
sys.stdout.write("\t".join([task_id, note, body]))
PY
)"

# Nothing finished to surface → allow the stop.
[ -n "$picked" ] || exit 0

task_id="${picked%%$'\t'*}"
rest="${picked#*$'\t'}"
note="${rest%%$'\t'*}"
body="${rest#*$'\t'}"
# Restore literal newlines in the body for a readable relay.
body="${body//\\n/$'\n'}"

# Emit the block decision as JSON, building the reason safely via python3 so
# embedded quotes/newlines in the result are escaped correctly.
TASK_ID="$task_id" NOTE="$note" BODY="$body" python3 - <<'PY'
import json, os

task_id = os.environ["TASK_ID"]
note = os.environ["NOTE"]
body = os.environ["BODY"]
reason = (
    "A background task you dispatched (" + task_id + ") just finished" + note
    + ". Relay its result to the user verbatim, then stop:\n\n" + body
)
print(json.dumps({"decision": "block", "reason": reason}))
PY
