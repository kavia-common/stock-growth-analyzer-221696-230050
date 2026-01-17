#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/stock-growth-analyzer-221696-230050/stock_data_backend"
VENV_PY="$WORKSPACE/.venv/bin/python"
if [ -x "$VENV_PY" ]; then
  exec "$VENV_PY" -m uvicorn main:app --host 0.0.0.0 --port 8000
else
  exec python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
fi
