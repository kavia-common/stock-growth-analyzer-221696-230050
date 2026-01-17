#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="/home/kavia/workspace/code-generation/stock-growth-analyzer-221696-230050/stock_data_backend"
cd "$WORKSPACE"
VENV_PY="$WORKSPACE/.venv/bin/python"
PY=${VENV_PY}
[ -x "$PY" ] || PY=python3
LOG="$WORKSPACE/validation.log"
TAIL="$WORKSPACE/validation_tail.log"
PIDFILE="$WORKSPACE/stock_data_backend.pid"
: >"$LOG" || true
# start uvicorn in a new session using setsid, capture leader pid
setsid "$PY" -m uvicorn main:app --host 0.0.0.0 --port 8000 >"$LOG" 2>&1 &
LEADER_PID=$!
# persist leader pid
echo "$LEADER_PID" > "$PIDFILE"
# derive PGID explicitly for reliable group termination
PGID=$(ps -o pgid= "$LEADER_PID" 2>/dev/null | tr -d ' ' || true)
if [ -z "$PGID" ]; then
  PGID=$LEADER_PID
fi
# wait with incremental backoff for /health (up to ~21s total: 1+2+3+4+5+6)
RETRIES=6
SLEEP=1
READY=0
for i in $(seq 1 $RETRIES); do
  sleep $SLEEP
  if curl -sSf http://127.0.0.1:8000/health >/dev/null 2>&1; then
    READY=1
    break
  fi
  SLEEP=$((SLEEP+1))
done
# capture last lines for quick debugging
tail -n 200 "$LOG" >"$TAIL" || true
if [ "$READY" -ne 1 ]; then
  echo "server failed to respond; see $TAIL" >&2
  # attempt cleanup: terminate process group by PGID to avoid orphaned workers
  kill -TERM -- -$PGID >/dev/null 2>&1 || true
  sleep 1
  kill -KILL -- -$PGID >/dev/null 2>&1 || true
  rm -f "$PIDFILE" || true
  exit 15
fi
# on success, show health endpoint and graceful cleanup
curl -sS http://127.0.0.1:8000/health || true
# cleanup: terminate entire process group reliably
kill -TERM -- -$PGID >/dev/null 2>&1 || true
sleep 1
kill -KILL -- -$PGID >/dev/null 2>&1 || true
rm -f "$PIDFILE" || true
# reap any terminated children
wait 2>/dev/null || true
exit 0
